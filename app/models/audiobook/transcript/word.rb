class Audiobook::Transcript::Word < ApplicationRecord
  self.table_name = "audiobook_transcript_words"

  belongs_to :transcript, class_name: "Audiobook::Transcript"

  default_scope { order(:position) }

  scope :covering, ->(time_ms) {
    where("start_time_ms <= ? AND end_time_ms > ?", time_ms, time_ms)
  }

  def duration_ms
    end_time_ms - start_time_ms
  end
end
