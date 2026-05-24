require "open3"

module Audio
  # One ffprobe invocation over an audio file, exposing the format tags,
  # chapter atoms, and duration the ingestion pipeline needs so each caller
  # doesn't re-shell out for the same data.
  class Probe
    def self.read(source_path) = new(source_path).read

    def initialize(source_path)
      @source_path = source_path
    end

    def read
      output, status = Open3.capture2(
        "ffprobe", "-v", "quiet", "-print_format", "json",
        "-show_chapters", "-show_format", @source_path
      )
      raise "ffprobe failed for #{@source_path}" unless status.success?

      @data = JSON.parse(output)
      self
    end

    def tags
      @data.dig("format", "tags") || {}
    end

    def chapters
      @data["chapters"] || []
    end

    def duration_ms
      ((@data.dig("format", "duration") || 0).to_f * 1_000).round
    end
  end
end
