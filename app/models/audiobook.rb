class Audiobook < ApplicationRecord
  include AudioIngestion

  belongs_to :user
  has_one_attached :audio

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }

  def display_title
    title.presence || audio.filename.to_s
  end
end
