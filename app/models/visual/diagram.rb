class Visual::Diagram < ApplicationRecord
  include Visual::Kind

  validates :nodes, :edges, presence: true

  def glyph = "*"
end
