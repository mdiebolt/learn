class Audiobook < ApplicationRecord
  include Authored, Ingestible, Chaptered, Covered, Transcribable

  belongs_to :user

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def extract_title_author_and_cover!
    extract_title!
    extract_author!
    extract_cover!
  end

  def extract_from_audio_source_file!
    processing!
    detect_chapters!
    ready!
  end
end
