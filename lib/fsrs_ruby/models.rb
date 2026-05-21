# frozen_string_literal: true

module FsrsRuby
  # State enum - Card states
  module State
    NEW = 0
    LEARNING = 1
    REVIEW = 2
    RELEARNING = 3

    def self.valid?(value)
      [NEW, LEARNING, REVIEW, RELEARNING].include?(value)
    end

    def self.from_string(str)
      const_get(str.upcase.to_sym)
    rescue NameError
      raise ArgumentError, "Invalid state: #{str}"
    end

    def self.to_string(value)
      case value
      when NEW then 'New'
      when LEARNING then 'Learning'
      when REVIEW then 'Review'
      when RELEARNING then 'Relearning'
      else raise ArgumentError, "Invalid state value: #{value}"
      end
    end
  end

  # Rating enum - Review ratings
  module Rating
    MANUAL = 0
    AGAIN = 1
    HARD = 2
    GOOD = 3
    EASY = 4

    def self.valid?(value)
      (MANUAL..EASY).cover?(value)
    end

    def self.from_string(str)
      const_get(str.upcase.to_sym)
    rescue NameError
      raise ArgumentError, "Invalid rating: #{str}"
    end

    def self.to_string(value)
      case value
      when MANUAL then 'Manual'
      when AGAIN then 'Again'
      when HARD then 'Hard'
      when GOOD then 'Good'
      when EASY then 'Easy'
      else raise ArgumentError, "Invalid rating value: #{value}"
      end
    end
  end

  # Card class representing a flashcard
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

  # ReviewLog class for tracking review history
  class ReviewLog
    attr_accessor :rating, :state, :due, :stability, :difficulty,
                  :elapsed_days, :last_elapsed_days, :scheduled_days,
                  :learning_steps, :review

    def initialize(
      rating:,
      state:,
      due:,
      stability:,
      difficulty:,
      elapsed_days:,
      last_elapsed_days:,
      scheduled_days:,
      learning_steps:,
      review:
    )
      @rating = rating
      @state = state
      @due = due
      @stability = stability.to_f
      @difficulty = difficulty.to_f
      @elapsed_days = elapsed_days
      @last_elapsed_days = last_elapsed_days
      @scheduled_days = scheduled_days
      @learning_steps = learning_steps
      @review = review
    end

    def to_h
      {
        rating: @rating,
        state: @state,
        due: @due,
        stability: @stability,
        difficulty: @difficulty,
        elapsed_days: @elapsed_days,
        last_elapsed_days: @last_elapsed_days,
        scheduled_days: @scheduled_days,
        learning_steps: @learning_steps,
        review: @review
      }
    end
  end

  # RecordLogItem - Container for card and log pair
  RecordLogItem = Struct.new(:card, :log, keyword_init: true)

  # Parameters class for FSRS parameters
  class Parameters
    attr_accessor :request_retention, :maximum_interval, :w, :enable_fuzz,
                  :enable_short_term, :learning_steps, :relearning_steps

    def initialize(
      request_retention: Constants::DEFAULT_REQUEST_RETENTION,
      maximum_interval: Constants::DEFAULT_MAXIMUM_INTERVAL,
      w: Constants::DEFAULT_WEIGHTS.dup,
      enable_fuzz: Constants::DEFAULT_ENABLE_FUZZ,
      enable_short_term: Constants::DEFAULT_ENABLE_SHORT_TERM,
      learning_steps: Constants::DEFAULT_LEARNING_STEPS.dup,
      relearning_steps: Constants::DEFAULT_RELEARNING_STEPS.dup
    )
      @request_retention = request_retention
      @maximum_interval = maximum_interval
      @w = w
      @enable_fuzz = enable_fuzz
      @enable_short_term = enable_short_term
      @learning_steps = learning_steps
      @relearning_steps = relearning_steps
    end

    def to_h
      {
        request_retention: @request_retention,
        maximum_interval: @maximum_interval,
        w: @w,
        enable_fuzz: @enable_fuzz,
        enable_short_term: @enable_short_term,
        learning_steps: @learning_steps,
        relearning_steps: @relearning_steps
      }
    end
  end
end
