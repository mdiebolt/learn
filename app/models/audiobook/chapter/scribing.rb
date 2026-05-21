module Audiobook::Chapter::Scribing
  extend ActiveSupport::Concern

  # Transcribes just this chapter's audio range. Idempotent: a retry deletes
  # any previously-saved words for this chapter and reinserts.
  def transcribe_segment!(force: false)
    return if transcription_ready? && !force
    raise "audiobook has no audio attached" unless audiobook.audio.attached?

    transcription_transcribing!
    audiobook.audio.open do |file|
      Audio::Segment.extract(file.path, start_time_ms, end_time_ms) do |segment_path|
        persist_words(ElevenLabs::Scribe.new.transcribe(segment_path))
      end
    end
    transcription_ready!
  end

  private

  def persist_words(response)
    atoms = (response["words"] || []).select { |w| w["type"] == "word" }
    now = Time.current

    transaction do
      Audiobook::Chapter::Word.where(chapter_id: id).delete_all
      rows = atoms.map.with_index do |atom, i|
        text = atom["text"]
        {
          chapter_id: id,
          text: text,
          start_time_ms: start_time_ms + (atom["start"].to_f * 1000).round,
          end_time_ms: start_time_ms + (atom["end"].to_f * 1000).round,
          position: i,
          orp_index: Audiobook::Chapter::Word.compute_orp_for(text),
          created_at: now,
          updated_at: now
        }
      end
      Audiobook::Chapter::Word.insert_all!(rows) if rows.any?
    end
  end
end
