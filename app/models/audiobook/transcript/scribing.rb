module Audiobook::Transcript::Scribing
  extend ActiveSupport::Concern

  # Idempotent: returns early if already transcribed, unless force: true.
  # Resets per-chapter state and fans out one ScribeJob per chapter; the
  # transcript stays :transcribing until #settle_chapter! finalizes it.
  def dispatch_chapter_scribes!(force: false)
    return if words.exists? && !force
    raise "audiobook has no audio attached" unless audiobook.audio.attached?

    chapters = audiobook.chapters.to_a
    transaction do
      words.delete_all
      Audiobook::Chapter.where(id: chapters.map(&:id)).update_all(transcription_status: :pending)
    end
    update!(progress_message: chapter_progress_message(0, chapters.size))
    chapters.each { |chapter| Audiobook::Chapter::ScribeJob.perform_later(chapter) }
  end

  # Called by each chapter job once it reaches a terminal state. Serialized via
  # a row lock so the last finishers don't race on the transcript status: while
  # chapters remain, it advances the progress message; once all are settled it
  # flips to :ready, or :failed if any chapter failed.
  def settle_chapter!
    with_lock do
      chapters = audiobook.chapters.reload
      in_flight = chapters.any? { |c| c.transcription_pending? || c.transcription_transcribing? }

      if in_flight
        return unless transcribing?
        done = chapters.count(&:transcription_ready?)
        update!(progress_message: chapter_progress_message(done, chapters.size))
      elsif chapters.any?(&:transcription_failed?)
        update!(status: :failed, progress_message: nil)
      else
        update!(status: :ready, progress_message: nil)
      end
    end
  end

  private

  def chapter_progress_message(done, total)
    "Transcribed #{done} of #{total} chapters…"
  end
end
