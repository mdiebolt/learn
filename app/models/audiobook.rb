class Audiobook < ApplicationRecord
  include Chaptered, Ingestible, Tagged, Transcribing

  belongs_to :user

  has_one_attached :cover

  enum :status, { queued: 0, ingesting: 1, ingested: 2, errored: 3 }

  scope :recent, -> { order(created_at: :desc) }
end
