class Audiobook < ApplicationRecord
  include AudioIngestion, ChapterDetection

  belongs_to :user

  has_many :chapters, class_name: "Audiobook::Chapter", dependent: :destroy
  has_one :transcript, class_name: "Audiobook::Transcript", dependent: :destroy

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def display_title
    title.presence || audio.filename.to_s
  end

  def start_transcription!
    (transcript || create_transcript!).update!(status: :pending, progress_message: nil)
    Audiobook::ScribeJob.perform_later(id)
  end
end
