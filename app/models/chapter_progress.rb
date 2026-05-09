class ChapterProgress < ApplicationRecord
  belongs_to :user
  belongs_to :chapter, class_name: "Audiobook::Chapter"

  def completed?
    completed_at.present?
  end

  def fraction_through(chapter)
    return 1.0 if completed?
    return 0.0 if chapter.duration_ms <= 0

    elapsed = (progress_ms - chapter.start_time_ms).clamp(0, chapter.duration_ms)
    elapsed.to_f / chapter.duration_ms
  end

  def record(attrs)
    self.progress_ms = attrs[:progress_ms].to_i if attrs.key?(:progress_ms)
    self.completed_at ||= Time.current if attrs[:completed].to_s == "true"
    save
  end
end
