class Audiobook::Chapter::Card::FreeResponse < ApplicationRecord
  include Kind

  validates :question, :reference_answer, presence: true

  def glyph = ">"
end
