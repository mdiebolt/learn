class Audiobook::Chapter::Card::Ordering < ApplicationRecord
  include Kind

  validates :prompt, :items, presence: true

  def glyph = "#"

  def shuffled_items
    items.each_with_index.to_a.shuffle
  end
end
