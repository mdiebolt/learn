require "open3"

module Audiobook::Chaptered
  extend ActiveSupport::Concern

  included do
    has_many :chapters, class_name: "Audiobook::Chapter", dependent: :destroy
  end

  def detect_chapters!
    audio.open do |file|
      probe_data = ffprobe(file.path)
      duration = ((probe_data.dig("format", "duration") || 0).to_f * 1000).round
      atoms = probe_data["chapters"] || []

      transaction do
        chapters.destroy_all
        if atoms.empty?
          chapters.create!(title: "Chapter 1", start_time_ms: 0, end_time_ms: duration, position: 0)
        else
          atoms.each_with_index { |atom, position| create_from_atom(atom, position) }
        end
        update!(duration_ms: duration)
      end
    end
  end

  private

  def create_from_atom(atom, position)
    chapters.create!(
      title: atom.dig("tags", "title").presence || "Chapter #{position + 1}",
      start_time_ms: (atom["start_time"].to_f * 1000).round,
      end_time_ms: (atom["end_time"].to_f * 1000).round,
      position: position
    )
  end

  def ffprobe(path)
    output, status = Open3.capture2(
      "ffprobe", "-v", "quiet", "-print_format", "json",
      "-show_chapters", "-show_format", path
    )
    raise "ffprobe failed for #{path}" unless status.success?
    JSON.parse(output)
  end
end
