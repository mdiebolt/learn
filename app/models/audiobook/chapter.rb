class Audiobook::Chapter < ApplicationRecord
  belongs_to :audiobook
  has_many :progresses, dependent: :destroy

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
