class ChapterProgress < ApplicationRecord
  belongs_to :user
  belongs_to :chapter, class_name: "Audiobook::Chapter"

  def completed?
    completed_at.present?
  end
end
