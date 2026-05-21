class Audiobook::Chapter::Card < ApplicationRecord
  delegated_type :kind, types: %w[
    Audiobook::Chapter::Card::MultipleChoice
    Audiobook::Chapter::Card::Cloze
    Audiobook::Chapter::Card::FreeResponse
    Audiobook::Chapter::Card::Ordering
    Audiobook::Chapter::Card::Matching
  ], dependent: :destroy

  belongs_to :user
  belongs_to :audiobook_chapter, class_name: "Audiobook::Chapter"
  belongs_to :study_guide,
    class_name: "Audiobook::Chapter::StudyGuide",
    foreign_key: :audiobook_chapter_study_guide_id,
    optional: true

  has_many :reviews,
    class_name: "Audiobook::Chapter::Card::Review",
    foreign_key: :audiobook_chapter_card_id,
    dependent: :destroy

  scope :due, ->(now = Time.current) { where("due <= ?", now) }

  def self.kind_class_for(slug)
    kind_types.find { |t| t.demodulize.underscore == slug.to_s }&.constantize
  end

  def chapter
    audiobook_chapter
  end

  def to_fsrs
    FsrsRuby::Card.new(
      due: due, stability: stability, difficulty: difficulty,
      elapsed_days: elapsed_days, scheduled_days: scheduled_days,
      learning_steps: learning_steps, reps: reps, lapses: lapses,
      state: state, last_review: last_review
    )
  end

  def apply_review!(rating:, response: nil, now: Time.current)
    result = Fsrs.instance.next(to_fsrs, now, rating)
    transaction do
      reviews.create!(
        rating: rating, response: response, reviewed_at: now,
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
