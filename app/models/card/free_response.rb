class Card::FreeResponse < ApplicationRecord
  include Card::Kind

  validates :question, :reference_answer, presence: true

  def glyph = ">"
end
