module Audiobook::Transcript::Scribing
  extend ActiveSupport::Concern

  PERSIST_BATCH_SIZE = 1_000

  # Idempotent: returns early if already transcribed, unless force: true.
  # ScribeJob owns the top-level :transcribing/:ready/:failed transitions;
  # this method advances the human-readable progress_message through the
  # internal stages (uploading → awaiting Scribe → saving words).
  def populate_from_scribe!(force: false)
    return if words.exists? && !force
    raise "audiobook has no audio attached" unless audiobook.audio.attached?

    update!(progress_message: "Uploading audio…")
    audiobook.audio.open do |file|
      update!(progress_message: "Awaiting Scribe (this takes a few minutes per hour of audio)…")
      response = ElevenLabs::Scribe.new.transcribe(file.path)
      persist_response(response)
    end
    update!(progress_message: nil)
  end

  private

  def persist_response(response)
    word_atoms = (response["words"] || []).select { |w| w["type"] == "word" }
    now = Time.current

    transaction do
      words.delete_all
      update!(raw_response: response, progress_message: "Saving 0 of #{word_atoms.size} words…")

      saved = 0
      word_atoms.each_slice(PERSIST_BATCH_SIZE).with_index do |batch, batch_index|
        rows = batch.map.with_index do |atom, i|
          text = atom["text"]
          {
            transcript_id: id,
            text: text,
            start_time_ms: (atom["start"].to_f * 1000).round,
            end_time_ms: (atom["end"].to_f * 1000).round,
            position: batch_index * PERSIST_BATCH_SIZE + i,
            orp_index: Audiobook::Transcript::Word.compute_orp_for(text),
            created_at: now,
            updated_at: now
          }
        end
        Audiobook::Transcript::Word.insert_all!(rows)
        saved += batch.size
        update!(progress_message: "Saving #{saved} of #{word_atoms.size} words…")
      end
    end
  end
end
