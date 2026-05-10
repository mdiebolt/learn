class Audiobook < ApplicationRecord
  include Ingestible, Chaptered

  belongs_to :user

  has_one :transcript, class_name: "Audiobook::Transcript", dependent: :destroy

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def transcribe!
    (transcript || create_transcript!).update!(status: :pending, progress_message: nil)
    Audiobook::ScribeJob.perform_later(id)
  end
end
