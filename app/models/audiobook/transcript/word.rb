class Audiobook::Transcript::Word < ApplicationRecord
  include WordPositioning

  self.table_name = "audiobook_transcript_words"

  belongs_to :transcript, class_name: "Audiobook::Transcript"

  default_scope { order(:position) }

  scope :covering, ->(time_ms) {
    where("start_time_ms <= ? AND end_time_ms > ?", time_ms, time_ms)
  }

  scope :between, ->(from_ms, to_ms) {
    where("start_time_ms >= ? AND start_time_ms < ?", from_ms, to_ms)
  }

  def self.playback_payload(scope = all)
    scope.pluck(:text, :start_time_ms, :orp_index).map { |text, start_ms, orp|
      { text: text, start: start_ms, orp: orp }
    }
  end

  def duration_ms
    end_time_ms - start_time_ms
  end
end
