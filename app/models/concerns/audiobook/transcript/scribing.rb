module Audiobook::Transcript::Scribing
  extend ActiveSupport::Concern

  # Idempotent: returns early if already transcribed, unless force: true.
  # ScribeJob owns status transitions; this method assumes the caller already
  # set status to :transcribing.
  def populate_from_scribe!(force: false)
    return if words.exists? && !force
    raise "audiobook has no audio attached" unless audiobook.audio.attached?

    audiobook.audio.open do |file|
      response = ElevenLabs::Scribe.new.transcribe(file.path)
      persist_response(response)
    end
  end

  private

  def persist_response(response)
    transaction do
      words.destroy_all
      update!(raw_response: response)

      word_atoms = (response["words"] || []).select { |w| w["type"] == "word" }
      word_atoms.each_with_index do |atom, position|
        words.create!(
          text: atom["text"],
          start_time_ms: (atom["start"].to_f * 1000).round,
          end_time_ms: (atom["end"].to_f * 1000).round,
          position: position
        )
      end
    end
  end
end
