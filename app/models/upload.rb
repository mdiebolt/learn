class Upload < ApplicationRecord
  include EpubParsing
  include ChapterExtraction

  belongs_to :user
  has_many :chapters, class_name: "Upload::Chapter", dependent: :destroy
  has_one_attached :source_file

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  validates :source_file, presence: true

  def process!
    transaction do
      processing!
      extract_metadata_from_epub!
      extract_chapters_from_epub!
      update!(status: :ready, processed_at: Time.current)
    end
  rescue => e
    failed!
    Rails.logger.error("[Upload] Processing failed for #{id}: #{e.message}")
    raise e
  end
end
