class Audiobook::Chapter::ScribeJob < ApplicationJob
  queue_as :default

  # ElevenLabs allows at most 12 concurrent speech-to-text requests per
  # subscription. Cap the whole fan-out below that — a constant key makes the
  # semaphore global across audiobooks — so a book with many chapters (or
  # several books at once) can't blow the limit. The duration outlives the
  # Scribe HTTP timeout (1800s) so a long-running slice keeps its slot.
  limits_concurrency to: 8, key: ->(_chapter) { "eleven_labs_scribe" }, duration: 35.minutes

  retry_on ElevenLabs::Scribe::RateLimitError, wait: :polynomially_longer, attempts: 8 do |job, error|
    chapter = job.arguments.first
    chapter.transcription_failed!
    Rails.logger.error("[Audiobook::Chapter::ScribeJob] #{chapter.id} failed after retries: #{error.message}")
  end

  def perform(chapter)
    chapter.transcribe_segment!
  rescue ElevenLabs::Scribe::RateLimitError
    raise
  rescue => e
    chapter.transcription_failed!
    Rails.logger.error("[Audiobook::Chapter::ScribeJob] #{chapter.id} failed: #{e.message}")
    raise
  end
end
