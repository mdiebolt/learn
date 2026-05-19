class Audiobook::IngestJob < ApplicationJob
  queue_as :default

  def perform(audiobook)
    audiobook.extract_from_audio_source_file!
  rescue => e
    audiobook.failed!
    Rails.logger.error("[Audiobook::IngestJob] #{audiobook.id} failed: #{e.message}")
    raise
  end
end
