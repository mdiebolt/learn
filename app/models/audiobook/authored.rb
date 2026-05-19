require "open3"

module Audiobook::Authored
  extend ActiveSupport::Concern

  AUTHOR_TAGS = %w[author artist album_artist].freeze

  def extract_author!
    audio.open do |file|
      tags = probe_format_tags(file.path)
      author = AUTHOR_TAGS.filter_map { |key| tags[key].presence }.first
      next if author.blank?

      update!(author: author)
    end
  end

  def extract_title!
    audio.open do |file|
      title = probe_format_tags(file.path)["title"].presence
      next if title.blank?

      update!(title: title)
    end
  end

  private

  def probe_format_tags(source_path)
    output, status = Open3.capture2(
      "ffprobe", "-v", "quiet", "-print_format", "json",
      "-show_format", source_path
    )
    return {} unless status.success?

    JSON.parse(output).dig("format", "tags") || {}
  rescue JSON::ParserError
    {}
  end
end
