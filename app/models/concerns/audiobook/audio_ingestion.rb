module Audiobook::AudioIngestion
  extend ActiveSupport::Concern

  ACCEPTED_EXTENSIONS = %w[.m4b .mp3].freeze

  included do
    validates :audio, presence: true
    validate :audio_is_supported_format
    after_create_commit :enqueue_ingestion
  end

  private

  def audio_is_supported_format
    return unless audio.attached?

    extension = File.extname(audio.filename.to_s).downcase
    return if ACCEPTED_EXTENSIONS.include?(extension)

    errors.add(:audio, "must be an M4B or MP3 file")
  end

  def enqueue_ingestion
    Audiobook::IngestJob.perform_later(id)
  end
end
