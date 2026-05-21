class Audiobook::Chapter::Card::Cloze < ApplicationRecord
  include Audiobook::Chapter::Card::Kind

  validates :text, :answers, presence: true
end
