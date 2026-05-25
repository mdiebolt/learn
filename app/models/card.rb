class Card < ApplicationRecord
  delegated_type :kind, types: %w[
    Card::MultipleChoice
    Card::Cloze
    Card::FreeResponse
    Card::Ordering
    Card::Matching
  ], dependent: :destroy

  belongs_to :user
  belongs_to :chapter
  belongs_to :study_guide, optional: true

  has_many :reviews, dependent: :destroy

  scope :due, ->(now = Time.current) { where("due <= ?", now) }

  def self.kind_class_for(slug)
    kind_types.find { it.demodulize.underscore == slug.to_s }&.constantize
  end

  delegate :glyph, to: :kind

  def name
    kind.model_name.element.titleize
  end

  def to_fsrs
    FsrsRuby::Card.new(
      due:, stability:, difficulty:,
      elapsed_days:, scheduled_days:,
      learning_steps:, reps:, lapses:,
      state:, last_review:
    )
  end

  def review!(rating:, response: nil, now: Time.current)
    result = Fsrs.instance.next(to_fsrs, now, rating)
    transaction do
      reviews.create!(
        rating:, response:, reviewed_at: now,
        prior_state: state, prior_due: due,
        prior_stability: stability, prior_difficulty: difficulty,
        prior_elapsed_days: elapsed_days,
        last_elapsed_days: result.log.last_elapsed_days,
        scheduled_days: result.log.scheduled_days,
        learning_steps: result.log.learning_steps
      )
      update!(result.card.to_h)
    end
  end
end
