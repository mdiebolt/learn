class User < ApplicationRecord
  WPM_OPTIONS = [ 150, 200, 250, 300, 400 ].freeze

  has_secure_password

  with_options dependent: :destroy do
    has_many :sessions
    has_many :audiobooks
    has_many :chapter_progresses, class_name: "Chapter::Progress"
    has_many :study_guides
    has_many :cards
  end

  has_many :chapters, through: :audiobooks

  normalizes :email_address, with: -> { it.strip.downcase }

  validates :wpm, inclusion: { in: WPM_OPTIONS }

  def reset_password(attrs)
    transaction do
      update(attrs).tap { |ok| sessions.destroy_all if ok }
    end
  end
end
