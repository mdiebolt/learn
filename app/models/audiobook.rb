class Audiobook < ApplicationRecord
  include Chaptered, Ingestible, Tagged, Transcribing

  belongs_to :user

  has_one_attached :cover

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def progresses_by_chapter_id(user)
    Chapter::Progress.where(user:, chapter: chapters).index_by(&:chapter_id)
  end

  def study_guides_by_chapter_id(user)
    StudyGuide.where(user:, chapter: chapters).order(:created_at).index_by(&:chapter_id)
  end

  def extract_from_audio_source_file!
    processing!
    extract_title_author_and_cover!
    detect_chapters!
    ready!
  end
end
