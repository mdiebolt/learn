class Audiobook::Chapter::Card::Matching < ApplicationRecord
  include Audiobook::Chapter::Card::Kind

  validates :prompt, :pairs, presence: true
end
