class Audiobook::Chapter < ApplicationRecord
  self.table_name = "audiobook_chapters"

  belongs_to :audiobook

  validates :title, presence: true
  validates :start_time_ms, :end_time_ms, :position, presence: true

  default_scope { order(:position) }

  def duration_ms
    end_time_ms - start_time_ms
  end
end
