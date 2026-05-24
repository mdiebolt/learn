class Audiobook < ApplicationRecord
  include Chaptered, Ingestible, Tagged, Transcribing

  belongs_to :user

  has_one_attached :cover

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  scope :recent, -> { order(created_at: :desc) }
end
