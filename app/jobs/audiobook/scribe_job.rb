class Audiobook::ScribeJob < ApplicationJob
  queue_as :default

  # The expensive job. Real money to ElevenLabs each time it runs.
  # Idempotent — re-running on a transcript that already has words is a no-op
  # unless force: true. Always invoked by an explicit user action, never auto.
  def perform(audiobook_id, force: false)
    audiobook = Audiobook.find(audiobook_id)
    transcript = audiobook.transcript || audiobook.create_transcript!

    transcript.transcribing!
    transcript.populate_from_scribe!(force: force)
    transcript.ready!
  rescue => e
    Audiobook.find_by(id: audiobook_id)&.transcript&.update(status: :failed)
    Rails.logger.error("[Audiobook::ScribeJob] #{audiobook_id} failed: #{e.message}")
    raise
  end
end
