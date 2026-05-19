class Audiobook::Chapter < ApplicationRecord
  include Scribing

  belongs_to :audiobook
  has_many :progresses, dependent: :destroy

  enum :transcription_status, { pending: 0, transcribing: 1, ready: 2, failed: 3 }, prefix: :transcription

  default_scope { order(:position) }

  def duration_ms
    end_time_ms - start_time_ms
  end

  def following
    audiobook.chapters.where("position > ?", position).first
  end

  def playback_words
    transcript = audiobook.transcript
    return [] unless transcript&.ready?

    Audiobook::Transcript::Word.playback_payload(
      transcript.words.between(start_time_ms, end_time_ms)
    )
  end
end
