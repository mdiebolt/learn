class Audiobook < ApplicationRecord
  include Ingestible, Chaptered, Covered, Transcribable

  belongs_to :user

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def extract_from_audio_source_file!
    processing!
    detect_chapters!
    extract_cover!
    ready!
  end
end
