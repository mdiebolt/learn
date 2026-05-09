class Audiobook::Chapter < ApplicationRecord
  self.table_name = "audiobook_chapters"

  belongs_to :audiobook
  has_many :progresses, class_name: "ChapterProgress", dependent: :destroy

  validates :title, presence: true
  validates :start_time_ms, :end_time_ms, :position, presence: true

  default_scope { order(:position) }

  def duration_ms
    end_time_ms - start_time_ms
  end

  def next_chapter
    audiobook.chapters.where("position > ?", position).first
  end

  def words_for_playback
    transcript = audiobook.transcript
    return [] unless transcript&.ready?

    transcript.words.between(start_time_ms, end_time_ms).for_playback
  end
end
