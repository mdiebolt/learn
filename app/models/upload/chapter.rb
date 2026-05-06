class Upload::Chapter < ApplicationRecord
  include WordProcessing

  self.table_name = "upload_chapters"

  belongs_to :upload
  has_one :audio_segment, class_name: "Upload::Chapter::AudioSegment", foreign_key: :chapter_id, dependent: :destroy

  validates :title, :position, :content, presence: true

  default_scope { order(:position) }

  def generate_audio!
    segment = audio_segment || create_audio_segment!(status: :pending)
    segment.generate!
  end

  def audio_ready?
    audio_segment&.ready?
  end

  def word_count
    content.split.size
  end

  def estimated_duration_minutes
    (word_count / 150.0).ceil
  end
end
