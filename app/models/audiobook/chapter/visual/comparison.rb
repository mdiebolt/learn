class Audiobook::Chapter::Visual::Comparison < ApplicationRecord
  include Audiobook::Chapter::Visual::Kind

  validates :columns, :rows, presence: true
end
