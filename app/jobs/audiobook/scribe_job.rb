class Audiobook::ScribeJob < ApplicationJob
  queue_as :default

  def perform(audiobook, force: false)
    transcript = audiobook.transcript || audiobook.create_transcript!

    transcript.transcribing!
    transcript.dispatch_chapter_scribes!(force:)
  rescue => e
    audiobook.transcript&.failed!
    Rails.logger.error("[Audiobook::ScribeJob] #{audiobook.id} failed: #{e.message}")
    raise
  end
end
