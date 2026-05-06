module Upload::EpubParsing
  extend ActiveSupport::Concern

  private

  DC_NAMESPACE = "http://purl.org/dc/elements/1.1/"
  OPF_NAMESPACE = "http://www.idpf.org/2007/opf"
  CONTAINER_NAMESPACE = "urn:oasis:names:tc:opendocument:xmlns:container"
  NCX_NAMESPACE = "http://www.daisy.org/z3986/2005/ncx/"

  def extract_metadata_from_epub!
    with_epub do |zip|
      opf_doc = opf_document(zip)

      update!(
        title: opf_doc.at_xpath("//dc:title", dc: DC_NAMESPACE)&.text,
        author: opf_doc.at_xpath("//dc:creator", dc: DC_NAMESPACE)&.text
      )
    end
  end

  def with_epub(&block)
    tempfile = download_to_tempfile
    Zip::File.open(tempfile.path, &block)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def download_to_tempfile
    tempfile = Tempfile.new(["upload", ".epub"])
    tempfile.binmode
    tempfile.write(source_file.download)
    tempfile.rewind
    tempfile
  end

  def opf_path(zip)
    container = Nokogiri::XML(zip.read("META-INF/container.xml"))
    container.at_xpath("//container:rootfile", container: CONTAINER_NAMESPACE)["full-path"]
  end

  def opf_document(zip)
    Nokogiri::XML(zip.read(opf_path(zip)))
  end

  def spine_items(zip)
    path = opf_path(zip)
    opf = opf_document(zip)
    manifest = build_manifest(opf)

    opf.xpath("//opf:spine/opf:itemref", opf: OPF_NAMESPACE).map do |itemref|
      idref = itemref["idref"]
      href = manifest[idref]
      content_path = resolve_path(path, href)

      {
        href: href,
        raw_html: zip.read(content_path)
      }
    end
  end

  def toc_titles(zip)
    path = opf_path(zip)
    opf = opf_document(zip)

    nav_item = opf.at_xpath("//opf:manifest/opf:item[@properties='nav']", opf: OPF_NAMESPACE)

    if nav_item
      extract_nav_toc(zip, resolve_path(path, nav_item["href"]))
    else
      ncx_item = opf.at_xpath("//opf:manifest/opf:item[@media-type='application/x-dtbncx+xml']", opf: OPF_NAMESPACE)
      ncx_item ? extract_ncx_toc(zip, resolve_path(path, ncx_item["href"])) : {}
    end
  end

  def build_manifest(opf_doc)
    opf_doc.xpath("//opf:manifest/opf:item", opf: OPF_NAMESPACE)
           .each_with_object({}) { |item, hash| hash[item["id"]] = item["href"] }
  end

  def resolve_path(opf_path, href)
    base_dir = File.dirname(opf_path)
    base_dir == "." ? href : File.join(base_dir, href)
  end

  def extract_nav_toc(zip, nav_path)
    doc = Nokogiri::HTML(zip.read(nav_path))
    doc.css("nav[epub|type='toc'] a, nav#toc a").each_with_object({}) do |link, hash|
      href = link["href"]&.split("#")&.first
      hash[href] = link.text.strip if href
    end
  end

  def extract_ncx_toc(zip, ncx_path)
    doc = Nokogiri::XML(zip.read(ncx_path))
    doc.xpath("//ncx:navPoint", ncx: NCX_NAMESPACE).each_with_object({}) do |point, hash|
      label = point.at_xpath("ncx:navLabel/ncx:text", ncx: NCX_NAMESPACE)&.text
      src = point.at_xpath("ncx:content", ncx: NCX_NAMESPACE)&.[]("src")&.split("#")&.first
      hash[src] = label if src && label
    end
  end
end
