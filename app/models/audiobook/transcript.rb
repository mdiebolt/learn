class Audiobook::Transcript < ApplicationRecord
  include Scribing

  belongs_to :audiobook
  has_many :words, class_name: "Audiobook::Transcript::Word",
    foreign_key: :transcript_id, dependent: :destroy

  enum :status, { pending: 0, transcribing: 1, ready: 2, failed: 3 }

  after_update_commit :broadcast_progress, if: :saved_change_to_progress_fields?

  private

  def saved_change_to_progress_fields?
    saved_change_to_status? || saved_change_to_progress_message?
  end

  def broadcast_progress
    broadcast_replace_to(
      [ audiobook, :transcript_badge ],
      target: ActionView::RecordIdentifier.dom_id(audiobook, :transcript_badge),
      partial: "audiobooks/transcript_badge",
      locals: { audiobook: audiobook }
    )
  end
end
