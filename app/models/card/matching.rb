class Card::Matching < ApplicationRecord
  include Card::Kind

  validates :prompt, :pairs, presence: true

  def glyph = "="

  def shuffled_answers
    pairs.map { it["right"] }.each_with_index.to_a.shuffle
  end
end
