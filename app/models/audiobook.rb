class Audiobook < ApplicationRecord
  include Chaptered, Ingestible, Tagged, Transcribable

  belongs_to :user

  has_one_attached :cover

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def extract_from_audio_source_file!
    processing!
    extract_title_author_and_cover!
    detect_chapters!
    ready!
  end
end
