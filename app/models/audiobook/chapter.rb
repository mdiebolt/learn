class Audiobook::Chapter < ApplicationRecord
  include Scribing

  belongs_to :audiobook
  has_many :words, class_name: "Audiobook::Chapter::Word", dependent: :destroy
  has_many :progresses, dependent: :destroy
  has_many :study_guides, class_name: "Audiobook::Chapter::StudyGuide",
    foreign_key: :audiobook_chapter_id, dependent: :destroy
  has_many :cards, class_name: "Audiobook::Chapter::Card",
    foreign_key: :audiobook_chapter_id, dependent: :destroy

  enum :transcription_status, { pending: 0, transcribing: 1, ready: 2, failed: 3 }, prefix: :transcription

  default_scope { order(:position) }

  after_update_commit :broadcast_audiobook_transcript_badge, if: :saved_change_to_transcription_status?

  def duration_ms
    end_time_ms - start_time_ms
  end

  def following
    audiobook.chapters.where("position > ?", position).first
  end

  def playback_words
    return [] unless transcription_ready?

    Audiobook::Chapter::Word.playback_payload(words)
  end

  private

  def broadcast_audiobook_transcript_badge
    broadcast_replace_to(
      [ audiobook, :transcript_badge ],
      target: ActionView::RecordIdentifier.dom_id(audiobook, :transcript_badge),
      partial: "audiobooks/transcript_badge",
      locals: { audiobook: audiobook }
    )
  end
end
