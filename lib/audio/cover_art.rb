require "open3"
require "tempfile"

module Audio
  # Pulls the embedded cover image out of an m4b/mp3. ffmpeg writes the first
  # attached picture stream out as JPEG; no stream means a non-zero exit, which
  # we treat as "no cover" rather than an error. Returns the JPEG bytes or nil.
  class CoverArt
    def self.extract(source_path) = new(source_path).extract

    def initialize(source_path)
      @source_path = source_path
    end

    def extract
      Tempfile.create(%w[cover .jpg]) do |out|
        _output, status = Open3.capture2e(
          "ffmpeg", "-y", "-i", @source_path,
          "-an", "-frames:v", "1", out.path
        )
        return nil unless status.success? && File.size?(out.path)

        File.binread(out.path)
      end
    end
  end
end
