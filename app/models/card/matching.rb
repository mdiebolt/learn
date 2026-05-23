class Card::Matching < ApplicationRecord
  include Card::Kind

  validates :prompt, :pairs, presence: true

  def glyph = "="

  def shuffled_answers
    pairs.map { |pair| pair["right"] }.each_with_index.to_a.shuffle
  end
end
