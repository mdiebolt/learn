module Audiobook::Chapter::Word::OptimalRecognitionPoint
  extend ActiveSupport::Concern

  # Spritz ORP table — the focal character index is chosen from the alphabetic
  # length of the word so the focal column stays roughly consistent.
  ORP_BY_LENGTH = {
    1..1   => 0,
    2..5   => 1,
    6..9   => 2,
    10..13 => 3
  }.freeze

  included do
    before_validation :assign_orp_index, on: :create
  end

  class_methods do
    def compute_orp_for(text)
      length = text.to_s.gsub(/[^[:alpha:]]/, "").length
      ORP_BY_LENGTH.find { |range, _| range.cover?(length) }&.last || 4
    end
  end

  def compute_orp_index
    self.class.compute_orp_for(text)
  end

  def before_orp
    text.to_s[0...orp_index]
  end

  def at_orp
    text.to_s[orp_index] || ""
  end

  def after_orp
    text.to_s[(orp_index + 1)..] || ""
  end

  private

  def assign_orp_index
    self.orp_index = compute_orp_index if orp_index.blank? || orp_index.zero?
  end
end
