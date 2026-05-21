class Audiobook::Chapter::StudyGuide < ApplicationRecord
  belongs_to :user
  belongs_to :audiobook_chapter, class_name: "Audiobook::Chapter"

  has_many :items, -> { order(:position) },
    class_name: "Audiobook::Chapter::StudyGuide::Item",
    foreign_key: :audiobook_chapter_study_guide_id, dependent: :destroy
  has_many :cards, class_name: "Audiobook::Chapter::Card",
    foreign_key: :audiobook_chapter_study_guide_id, dependent: :nullify
  has_many :visuals, class_name: "Audiobook::Chapter::Visual",
    foreign_key: :audiobook_chapter_study_guide_id, dependent: :destroy

  def chapter
    audiobook_chapter
  end
end
