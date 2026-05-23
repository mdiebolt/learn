class Audiobook::Chapter::StudyGuide::Item < ApplicationRecord
  belongs_to :study_guide, class_name: "Audiobook::Chapter::StudyGuide", foreign_key: :audiobook_chapter_study_guide_id
  belongs_to :itemable, polymorphic: true
end
