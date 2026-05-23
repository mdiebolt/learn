class Audiobook::Chapter::Card::MultipleChoice < ApplicationRecord
  include Kind

  validates :question, :options, presence: true
  validates :correct_index, presence: true, numericality: { only_integer: true }

  def glyph = "?"
end
