module Audiobook::Chapter::Scribing
  extend ActiveSupport::Concern

  # Each chapter owns a disjoint block of word positions so the parallel
  # chapter jobs never collide on the (transcript_id, position) unique index.
  # Chapter positions are unique per audiobook and ordered by time, and no
  # chapter holds anywhere near a million words, so blocks stay both unique
  # and globally time-ordered.
  WORD_POSITION_STRIDE = 1_000_000

  # Transcribes just this chapter's audio range. Idempotent: a retry deletes
  # this chapter's previously-saved words (a disjoint time slice) and reinserts.
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
    transcript = audiobook.transcript
    base_position = position * WORD_POSITION_STRIDE
    now = Time.current

    transcript.transaction do
      transcript.words.between(start_time_ms, end_time_ms).delete_all
      rows = atoms.map.with_index do |atom, i|
        text = atom["text"]
        {
          transcript_id: transcript.id,
          text: text,
          start_time_ms: start_time_ms + (atom["start"].to_f * 1000).round,
          end_time_ms: start_time_ms + (atom["end"].to_f * 1000).round,
          position: base_position + i,
          orp_index: Audiobook::Transcript::Word.compute_orp_for(text),
          created_at: now,
          updated_at: now
        }
      end
      Audiobook::Transcript::Word.insert_all!(rows) if rows.any?
    end
  end
end
