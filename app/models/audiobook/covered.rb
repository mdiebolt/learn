require "open3"

module Audiobook::Covered
  extend ActiveSupport::Concern

  included do
    has_one_attached :cover
  end

  def extract_cover!
    audio.open do |file|
      image = embedded_cover(file.path)
      next if image.blank?

      cover.attach(
        io: StringIO.new(image),
        filename: "#{id}-cover.jpg",
        content_type: "image/jpeg"
      )
    end
  end

  private

  # m4b/mp3 store cover art as an embedded image stream; ffmpeg writes the
  # first one out as JPEG. No stream means a non-zero exit, which we treat
  # as "no cover" rather than an error.
  def embedded_cover(source_path)
    Tempfile.create(%w[cover .jpg]) do |out|
      _output, status = Open3.capture2e(
        "ffmpeg", "-y", "-i", source_path,
        "-an", "-frames:v", "1", out.path
      )
      next nil unless status.success? && File.size?(out.path)

      File.binread(out.path)
    end
  end
end
