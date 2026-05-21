class User < ApplicationRecord
  WPM_OPTIONS = [ 150, 200, 250, 300, 400 ].freeze
  AUDIO_OFFSET_MS_RANGE = (-500..500).freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :audiobooks, dependent: :destroy
  has_many :chapter_progresses, class_name: "Audiobook::Chapter::Progress", dependent: :destroy
  has_many :study_guides, class_name: "Audiobook::Chapter::StudyGuide", dependent: :destroy
  has_many :cards, class_name: "Audiobook::Chapter::Card", dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :wpm, inclusion: { in: WPM_OPTIONS }
  validates :audio_offset_ms, numericality: { only_integer: true, in: AUDIO_OFFSET_MS_RANGE }

  def reset_password(attrs)
    transaction do
      update(attrs).tap { |ok| sessions.destroy_all if ok }
    end
  end
end
