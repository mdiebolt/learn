class Audiobook::Chapter::Card::Ordering < ApplicationRecord
  include Audiobook::Chapter::Card::Kind

  validates :prompt, :items, presence: true
end
