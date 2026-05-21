class Audiobook::Chapter::Card::FreeResponse < ApplicationRecord
  include Audiobook::Chapter::Card::Kind

  validates :question, :reference_answer, presence: true
end
