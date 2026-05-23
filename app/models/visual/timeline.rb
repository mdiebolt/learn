class Visual::Timeline < ApplicationRecord
  include Visual::Kind

  validates :events, presence: true

  def glyph = "~"
end
