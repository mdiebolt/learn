# frozen_string_literal: true

module FsrsRuby
  class Card
    attr_accessor :due, :stability, :difficulty, :elapsed_days, :scheduled_days,
                  :learning_steps, :reps, :lapses, :state, :last_review

    def initialize(
      due:,
      stability: 0.0,
      difficulty: 0.0,
      elapsed_days: 0,
      scheduled_days: 0,
      learning_steps: 0,
      reps: 0,
      lapses: 0,
      state: State::NEW,
      last_review: nil
    )
      @due = due
      @stability = stability.to_f
      @difficulty = difficulty.to_f
      @elapsed_days = elapsed_days
      @scheduled_days = scheduled_days
      @learning_steps = learning_steps
      @reps = reps
      @lapses = lapses
      @state = state
      @last_review = last_review
    end

    def clone
      Card.new(
        due: @due.dup,
        stability: @stability,
        difficulty: @difficulty,
        elapsed_days: @elapsed_days,
        scheduled_days: @scheduled_days,
        learning_steps: @learning_steps,
        reps: @reps,
        lapses: @lapses,
        state: @state,
        last_review: @last_review&.dup
      )
    end

    def to_h
      {
        due: @due,
        stability: @stability,
        difficulty: @difficulty,
        elapsed_days: @elapsed_days,
        scheduled_days: @scheduled_days,
        learning_steps: @learning_steps,
        reps: @reps,
        lapses: @lapses,
        state: @state,
        last_review: @last_review
      }
    end
  end
end
