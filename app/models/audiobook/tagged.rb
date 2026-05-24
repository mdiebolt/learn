module Audiobook::Tagged
  extend ActiveSupport::Concern

  AUTHOR_TAGS = %w[author artist album_artist].freeze

  included do
    before_validation :default_blank_title_from_filename, on: :create
  end

  # Best-effort: a tag-less or odd file should still ingest (title falls back
  # to the filename), so a probe failure here is logged, not raised.
  def extract_title_author_and_cover!
    audio.open do |file|
      set_title_and_author(Audio::Probe.read(file.path))
      save!
      attach_embedded_cover(file.path)
    end
  rescue => e
    Rails.logger.error("[Audiobook##{id}] metadata/cover extraction failed: #{e.message}")
  end

  private

  def default_blank_title_from_filename
    return if title.present?
    return unless audio.attached?

    self.title = File.basename(audio.filename.to_s, ".*")
  end

  def set_title_and_author(probe)
    tags = probe.tags
    self.title = tags["title"].presence || title
    self.author = AUTHOR_TAGS.filter_map { tags[it].presence }.first || author
  end

  def attach_embedded_cover(source_path)
    image = Audio::CoverArt.extract(source_path)
    return if image.blank?

    cover.attach(io: StringIO.new(image), filename: "#{id}-cover.jpg", content_type: "image/jpeg")
  end
end
