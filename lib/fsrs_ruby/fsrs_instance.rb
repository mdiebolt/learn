# frozen_string_literal: true

module FsrsRuby
  # Main FSRS class with public API
  class FSRSInstance < Algorithm
    def initialize(params = {})
      super(params)
      @strategy_handlers = {}
      @scheduler_class = @parameters.enable_short_term ? Schedulers::BasicScheduler : Schedulers::LongTermScheduler
    end

    # Register a strategy handler
    # @param mode [Symbol] Strategy mode (:scheduler, :learning_steps, :seed)
    # @param handler [Proc, Method] Strategy handler
    # @return [self]
    def use_strategy(mode, handler)
      raise ArgumentError, 'Handler must respond to :call' unless handler.respond_to?(:call)

      @strategy_handlers[mode] = handler
      self
    end

    # Clear strategy handler(s)
    # @param mode [Symbol, nil] Strategy mode to clear, or nil to clear all
    # @return [self]
    def clear_strategy(mode = nil)
      mode ? @strategy_handlers.delete(mode) : @strategy_handlers.clear
      self
    end

    # Preview all possible ratings for a card
    # @param card [Card, Hash] Card to review
    # @param now [Time, Integer, String] Review time
    # @return [Hash] { Rating::AGAIN =>, Rating::HARD =>, Rating::GOOD =>, Rating::EASY => }
    def repeat(card, now)
      scheduler = get_scheduler(card, now)
      scheduler.preview
    end

    # Apply a specific rating to a card
    # @param card [Card, Hash] Card to review
    # @param now [Time, Integer, String] Review time
    # @param grade [Integer] Rating (1=Again, 2=Hard, 3=Good, 4=Easy)
    # @return [RecordLogItem] { card:, log: }
    def next(card, now, grade)
      scheduler = get_scheduler(card, now)
      scheduler.review(grade)
    end

    # Get retrievability (probability of recall) for a card
    # @param card [Card, Hash] Card
    # @param now [Time, Integer, String, nil] Current time (defaults to Time.now)
    # @param format [Boolean] If true, return percentage string; if false, return decimal
    # @return [String, Float] Retrievability
    def get_retrievability(card, now = nil, format: true)
      card = card.is_a?(Card) ? card : TypeConverter.card(card)
      now = now ? TypeConverter.time(now) : Time.now

      elapsed_days = Helpers.date_diff(now, card.last_review || card.due, :days)
      retrievability = forgetting_curve(@parameters.w, elapsed_days, card.stability)

      format ? "#{(retrievability * 100).round(2)}%" : retrievability
    end

    # Rollback a review
    # @param card [Card] Card after review
    # @param log [ReviewLog] Review log
    # @return [Card] Card before the review
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

    # Reset card to NEW state
    # @param card [Card] Card to reset
    # @param now [Time, Integer, String] Current time
    # @param reset_count [Boolean] Whether to reset reps and lapses
    # @return [RecordLogItem] { card:, log: }
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

      scheduler_strategy = @strategy_handlers[:scheduler]
      scheduler_class = scheduler_strategy || @scheduler_class

      scheduler_class.new(card, now, self, @strategy_handlers)
    end
  end
end
