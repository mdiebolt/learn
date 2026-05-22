class Audiobook::Chapter::Visual::Timeline < ApplicationRecord
  include Audiobook::Chapter::Visual::Kind

  validates :events, presence: true

  def glyph = "~"
end
