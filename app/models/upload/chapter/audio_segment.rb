class Upload::Chapter::AudioSegment < ApplicationRecord
  include SpeechGeneration

  self.table_name = "upload_chapter_audio_segments"

  belongs_to :chapter, class_name: "Upload::Chapter"
  has_one_attached :audio_file

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  def word_at_time(seconds)
    timestamps.find do |t|
      seconds >= t["start"] && seconds < t["end"]
    end
  end

  def formatted_duration
    return "0:00" unless duration_seconds

    minutes = (duration_seconds / 60).floor
    seconds = (duration_seconds % 60).round

    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end
end
