class Audiobook::IngestJob < ApplicationJob
  queue_as :default

  def perform(audiobook_id)
    audiobook = Audiobook.find(audiobook_id)
    audiobook.processing!
    audiobook.detect_chapters!
    audiobook.ready!
  rescue => e
    Audiobook.find_by(id: audiobook_id)&.update(status: :failed)
    Rails.logger.error("[Audiobook::IngestJob] #{audiobook_id} failed: #{e.message}")
    raise
  end
end
