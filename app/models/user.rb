class User < ApplicationRecord
  WPM_OPTIONS = [ 150, 200, 250, 300, 400 ].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :audiobooks, dependent: :destroy
  has_many :chapter_progresses, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :wpm, inclusion: { in: WPM_OPTIONS }

  def reset_password(attrs)
    transaction do
      update(attrs).tap { |ok| sessions.destroy_all if ok }
    end
  end
end
