class Audiobook::Chapter::Word < ApplicationRecord
  include OptimalRecognitionPoint

  belongs_to :chapter, class_name: "Audiobook::Chapter"

  default_scope { order(:position) }

  scope :covering, ->(time_ms) {
    where("start_time_ms <= ? AND end_time_ms > ?", time_ms, time_ms)
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
