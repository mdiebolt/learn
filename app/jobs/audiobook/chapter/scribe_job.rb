class Audiobook::Chapter::ScribeJob < ApplicationJob
  queue_as :default

  def perform(chapter)
    begin
      chapter.transcribe_segment!
    rescue => e
      chapter.transcription_failed!
      Rails.logger.error("[Audiobook::Chapter::ScribeJob] #{chapter_id} failed: #{e.message}")
      raise
    ensure
      chapter.audiobook.transcript&.settle_chapter!
    end
  end
end
