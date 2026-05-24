class Chapter::Progress < ApplicationRecord
  belongs_to :user
  belongs_to :chapter

  def completed?
    completed_at.present?
  end

  def fraction_through(chapter)
    return 1.0 if completed?
    return 0.0 if chapter.duration_ms <= 0

    elapsed = (progress_ms - chapter.start_time_ms).clamp(0, chapter.duration_ms)
    elapsed.to_f / chapter.duration_ms
  end

  def completed=(value)
    self.completed_at ||= Time.current if value
  end

  def record(attrs)
    update(attrs.slice(:progress_ms, :completed))
  end
end
