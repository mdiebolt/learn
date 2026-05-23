class Card::MultipleChoice < ApplicationRecord
  include Card::Kind

  validates :question, :options, presence: true
  validates :correct_index, presence: true, numericality: { only_integer: true }

  def glyph = "?"
end
