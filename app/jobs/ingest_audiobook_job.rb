class IngestAudiobookJob < ApplicationJob
  queue_as :default

  def perform(audiobook)
    audiobook.extract_from_audio_source_file!
  rescue => e
    audiobook.errored!
    Rails.logger.error("[IngestAudiobookJob] #{audiobook.id} failed: #{e.message}")
    raise
  end
end
