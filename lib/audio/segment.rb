require "open3"
require "tempfile"

module Audio
  # Extracts a time range from an audio file into a standalone MP3 so each
  # chapter can be sent to Scribe independently. Yields the temp file path and
  # cleans it up afterward.
  class Segment
    def self.extract(source_path, start_time_ms, end_time_ms, &block)
      new(source_path, start_time_ms, end_time_ms).extract(&block)
    end

    def initialize(source_path, start_time_ms, end_time_ms)
      @source_path = source_path
      @start_time_ms = start_time_ms
      @end_time_ms = end_time_ms
    end

    def extract
      Tempfile.create([ "chapter_segment", ".mp3" ]) do |tempfile|
        output, status = Open3.capture2e(
          "ffmpeg", "-v", "error", "-y",
          "-ss", seconds(@start_time_ms), "-to", seconds(@end_time_ms),
          "-i", @source_path,
          "-vn", "-acodec", "libmp3lame", "-f", "mp3",
          tempfile.path
        )
        unless status.success?
          details = output.lines.last(20).join.strip
          raise "ffmpeg failed to slice #{@start_time_ms}–#{@end_time_ms}ms from #{@source_path}: #{details}"
        end
        yield tempfile.path
      end
    end

    private

    def seconds(ms)
      format("%.3f", ms / 1000.0)
    end
  end
end
