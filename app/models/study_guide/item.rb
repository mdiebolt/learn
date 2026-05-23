class StudyGuide::Item < ApplicationRecord
  belongs_to :study_guide
  belongs_to :itemable, polymorphic: true
end
