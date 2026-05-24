module Audiobook::Transcribing
  extend ActiveSupport::Concern

  # Idempotent: a force-less call against an already-transcribed book is a
  # no-op so the page can call this without re-billing ElevenLabs.
  def transcribe!(force: false)
    return if transcription_status == :ready && !force

    list = chapters.to_a
    return if list.empty?
    raise "audiobook has no audio attached" unless audio.attached?

    transaction do
      Chapter::Word.where(chapter_id: list.map(&:id)).delete_all
      Chapter.where(id: list.map(&:id)).update_all(transcription_status: :transcribing)
    end
    list.each { |chapter| TranscribeChapterJob.perform_later(chapter) }
  end

  # Aggregate state derived from the chapters' transcription_status. A book
  # with no chapters is :pending; once chapters exist we collapse them:
  # any :failed without anything still in flight wins; otherwise anything in
  # flight is :transcribing; otherwise all-ready is :ready; otherwise :pending.
  def transcription_status
    statuses = chapters.pluck(:transcription_status)
    return :pending if statuses.empty?

    counts = statuses.tally
    counts.default = 0

    if counts["failed"].positive? && counts["transcribing"].zero?
      :failed
    elsif counts["transcribing"].positive? || (counts["pending"].positive? && counts["ready"].positive?)
      :transcribing
    elsif counts["ready"] == statuses.size
      :ready
    else
      :pending
    end
  end

  def transcription_progress_message
    statuses = chapters.pluck(:transcription_status)
    return nil if statuses.empty?

    "Transcribed #{statuses.count('ready')} of #{statuses.size} chapters…"
  end
end
