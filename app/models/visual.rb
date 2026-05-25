class Visual < ApplicationRecord
  include Kindable

  belongs_to :study_guide
end
