module Audiobook::AudioIngestion
  extend ActiveSupport::Concern

  ACCEPTED_EXTENSIONS = %w[.m4b .mp3].freeze

  included do
    has_one_attached :audio

    validates :audio, presence: true
    validate :format_supported

    after_create_commit :enqueue_ingestion
  end

  private

  def format_supported
    return unless audio.attached?

    extension = File.extname(audio.filename.to_s).downcase
    return if ACCEPTED_EXTENSIONS.include?(extension)

    errors.add(:audio, "must be an M4B or MP3 file")
  end

  def enqueue_ingestion
    Audiobook::IngestJob.perform_later(id)
  end
end
