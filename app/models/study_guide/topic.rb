class StudyGuide::Topic < ApplicationRecord
  belongs_to :study_guide
  belongs_to :topical, polymorphic: true
end
