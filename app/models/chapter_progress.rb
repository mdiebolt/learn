class ChapterProgress < ApplicationRecord
  belongs_to :user
  belongs_to :chapter, class_name: "Audiobook::Chapter"

  def completed?
    completed_at.present?
  end

  def record(attrs)
    self.progress_ms = attrs[:progress_ms].to_i if attrs.key?(:progress_ms)
    self.completed_at ||= Time.current if attrs[:completed].to_s == "true"
    save
  end
end
