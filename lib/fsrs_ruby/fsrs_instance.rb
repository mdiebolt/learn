# frozen_string_literal: true

module FsrsRuby
  class FsrsInstance < Algorithm
    def initialize(params = {})
      super(params)
      @scheduler_class = @parameters.enable_short_term ? Schedulers::BasicScheduler : Schedulers::LongTermScheduler
    end

    # Preview all possible ratings for a card.
    # @return [Hash] { Rating::AGAIN =>, Rating::HARD =>, Rating::GOOD =>, Rating::EASY => }
    def repeat(card, now)
      get_scheduler(card, now).preview
    end

    # Apply a specific rating to a card.
    # @return [RecordLogItem] { card:, log: }
    def next(card, now, grade)
      get_scheduler(card, now).review(grade)
    end

    # Probability of recall for a card.
    # @param format [Boolean] true → percentage string, false → decimal
    def get_retrievability(card, now = nil, format: true)
      card = card.is_a?(Card) ? card : TypeConverter.card(card)
      now = now ? TypeConverter.time(now) : Time.now

      elapsed_days = Helpers.date_diff(now, card.last_review || card.due)
      retrievability = forgetting_curve(@parameters.w, elapsed_days, card.stability)

      format ? "#{(retrievability * 100).round(2)}%" : retrievability
    end

    # Undo a review: returns the card as it was before `log` was applied.
    def rollback(card, log)
      Card.new(
        due: log.due,
        stability: log.stability,
        difficulty: log.difficulty,
        elapsed_days: log.elapsed_days,
        scheduled_days: log.last_elapsed_days,
        learning_steps: log.learning_steps,
        reps: card.reps - 1,
        lapses: log.rating == Rating::AGAIN ? card.lapses - 1 : card.lapses,
        state: log.state,
        last_review: card.last_review
      )
    end

    # Reset a card to NEW.
    # @param reset_count [Boolean] also zero out reps/lapses
    def forget(card, now, reset_count: false)
      card = card.is_a?(Card) ? card : TypeConverter.card(card)
      now = now.is_a?(Time) ? now : TypeConverter.time(now)

      new_card = ParameterUtils.create_empty_card(now)
      new_card.reps = reset_count ? 0 : card.reps
      new_card.lapses = reset_count ? 0 : card.lapses

      log = ReviewLog.new(
        rating: Rating::MANUAL,
        state: card.state,
        due: card.due,
        stability: card.stability,
        difficulty: card.difficulty,
        elapsed_days: 0,
        last_elapsed_days: card.scheduled_days,
        scheduled_days: 0,
        learning_steps: 0,
        review: now
      )

      RecordLogItem.new(card: new_card, log: log)
    end

    private

    def get_scheduler(card, now)
      card = card.is_a?(Card) ? card : TypeConverter.card(card)
      now = now.is_a?(Time) ? now : TypeConverter.time(now)

      @scheduler_class.new(card, now, self)
    end
  end
end
