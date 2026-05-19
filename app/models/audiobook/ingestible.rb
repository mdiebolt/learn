module Audiobook::Ingestible
  extend ActiveSupport::Concern

  ACCEPTED_EXTENSIONS = %w[.m4b .mp3].freeze

  included do
    has_one_attached :audio

    validate :format_supported

    before_validation :default_title_from_filename, on: :create
    after_create_commit :enqueue_ingestion
  end

  private

  def format_supported
    return unless audio.attached?

    extension = File.extname(audio.filename.to_s).downcase
    return if ACCEPTED_EXTENSIONS.include?(extension)

    errors.add(:audio, "must be an M4B or MP3 file")
  end

  # Fallback only — the embedded title (Audiobook::Authored#extract_title!)
  # is the real public-facing title. When a file carries no title tag we
  # still want a clean label, so strip the extension: "Dune", not "Dune.m4b".
  def default_title_from_filename
    return if title.present?
    return unless audio.attached?

    self.title = File.basename(audio.filename.to_s, ".*")
  end

  def enqueue_ingestion
    Audiobook::IngestJob.perform_later(self)
  end
end
