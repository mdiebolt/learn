class Visual::Comparison < ApplicationRecord
  include Visual::Kind

  validates :columns, :rows, presence: true

  def glyph = "|"
end
