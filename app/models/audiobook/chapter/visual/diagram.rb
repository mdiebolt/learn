class Audiobook::Chapter::Visual::Diagram < ApplicationRecord
  include Audiobook::Chapter::Visual::Kind

  validates :nodes, :edges, presence: true
end
