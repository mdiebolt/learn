module Audiobook::Chaptered
  extend ActiveSupport::Concern

  included do
    has_many :chapters, dependent: :destroy
  end

  def detect_chapters!
    audio.open do |file|
      probe = Audio::Probe.read(file.path)

      transaction do
        chapters.destroy_all
        if probe.chapters.empty?
          chapters.create!(title: "Chapter 1", start_time_ms: 0, end_time_ms: probe.duration_ms, position: 0)
        else
          probe.chapters.each_with_index { |atom, position| create_from_atom(atom, position) }
        end
        update!(duration_ms: probe.duration_ms)
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
end
