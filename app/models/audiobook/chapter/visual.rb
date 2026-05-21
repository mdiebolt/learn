class Audiobook::Chapter::Visual < ApplicationRecord
  delegated_type :kind, types: %w[
    Audiobook::Chapter::Visual::Diagram
    Audiobook::Chapter::Visual::Timeline
    Audiobook::Chapter::Visual::Comparison
  ], dependent: :destroy

  belongs_to :study_guide,
    class_name: "Audiobook::Chapter::StudyGuide",
    foreign_key: :audiobook_chapter_study_guide_id
end
