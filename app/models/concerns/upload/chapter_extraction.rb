module Upload::ChapterExtraction
  extend ActiveSupport::Concern

  def extract_chapters_from_epub!
    with_epub do |zip|
      raw_chapters = parse_raw_chapters(zip)
      refined_chapters = refine_chapters_with_ai(raw_chapters)

      refined_chapters.each do |chapter_data|
        chapters.create!(
          position: chapter_data[:position],
          title: chapter_data[:title],
          content: chapter_data[:content]
        ).preprocess_words!
      end
    end
  end

  private

  def parse_raw_chapters(zip)
    toc = toc_titles(zip)

    spine_items(zip).map.with_index do |item, index|
      {
        position: index,
        title: toc[item[:href]] || "Chapter #{index + 1}",
        raw_html: item[:raw_html],
        content: html_to_text(item[:raw_html])
      }
    end
  end

  def html_to_text(html)
    doc = Nokogiri::HTML(html)
    doc.css("script, style, nav, header, footer").remove
    doc.css("body").text.gsub(/\n{3,}/, "\n\n").strip
  end

  def refine_chapters_with_ai(raw_chapters)
    summaries = raw_chapters.map do |ch|
      {
        index: ch[:position],
        title: ch[:title],
        word_count: ch[:content].split.size,
        first_500_chars: ch[:content][0, 500],
        last_200_chars: ch[:content][-200..] || ch[:content]
      }
    end

    analysis = request_chapter_analysis(summaries)

    (analysis["chapters"] || [])
      .select { |ch| ch["include"] && !ch["is_front_matter"] && !ch["is_back_matter"] }
      .map.with_index do |ch, new_position|
        original = raw_chapters[ch["original_index"]]
        {
          position: new_position,
          title: ch["suggested_title"] || original[:title],
          content: original[:content]
        }
      end
  end

  def request_chapter_analysis(summaries)
    response = anthropic_client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      system: chapter_analysis_system_prompt,
      messages: [{ role: "user", content: chapter_analysis_prompt(summaries) }]
    )

    text = response.content.first.text
    text = text.sub(/\A```json\s*/i, "").sub(/\A```\s*/i, "").sub(/```\s*\z/, "").strip
    JSON.parse(text)
  end

  def chapter_analysis_system_prompt
    <<~PROMPT
      You are analyzing the structure of an EPUB book that has been parsed into segments.
      Your job is to identify which segments are actual content chapters vs front/back matter,
      and to suggest better chapter titles where the extracted title is generic or missing.

      Respond with JSON only. No markdown fences, no explanation.
    PROMPT
  end

  def chapter_analysis_prompt(summaries)
    <<~PROMPT
      Here are the segments extracted from an EPUB:

      #{summaries.to_json}

      Analyze this structure and return JSON with:
      {
        "chapters": [
          {
            "original_index": 0,
            "include": true,
            "suggested_title": "Chapter 1: Introduction to Financial Statements",
            "is_front_matter": false,
            "is_back_matter": false
          }
        ]
      }

      Mark front matter (title pages, copyright, TOC, dedications) and back matter
      (appendices, indexes, about the author) appropriately. Only set include: true for
      actual content chapters the reader should study.
    PROMPT
  end

  def anthropic_client
    @anthropic_client ||= Anthropic::Client.new(api_key: Rails.application.credentials.dig(:anthropic, :api_key))
  end
end
