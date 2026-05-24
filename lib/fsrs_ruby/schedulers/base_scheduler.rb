module FsrsRuby
  module Schedulers
    class BaseScheduler
      attr_reader :last, :current, :review_time, :algorithm, :elapsed_days

      def initialize(card, now, algorithm)
        @last = card
        @current = @last.clone
        @review_time = now
        @algorithm = algorithm
        @next_cache = {}

        init
      end

      # Preview all possible outcomes
      def preview
        {
          Rating::AGAIN => review(Rating::AGAIN),
          Rating::HARD => review(Rating::HARD),
          Rating::GOOD => review(Rating::GOOD),
          Rating::EASY => review(Rating::EASY)
        }
      end

      def review(grade)
        raise ArgumentError, "Invalid grade: #{grade}" unless (Rating::AGAIN..Rating::EASY).cover?(grade)

        return @next_cache[grade] if @next_cache.key?(grade)

        result = case @current.state
        when State::NEW
                   new_state(grade)
        when State::LEARNING, State::RELEARNING
                   learning_state(grade)
        when State::REVIEW
                   review_state(grade)
        else
                   raise "Unknown state: #{@current.state}"
        end

        @next_cache[grade] = result
        result
      end

      protected

      def init
        @elapsed_days = if @last.last_review
                          Helpers.date_diff(@review_time, @last.last_review)
        else
                          0
        end

        @current.last_review = @review_time
        @current.reps += 1
      end

      def build_log(rating)
        ReviewLog.new(
          rating: rating,
          state: @last.state,
          due: @last.due,
          stability: @last.stability,
          difficulty: @last.difficulty,
          elapsed_days: @elapsed_days,
          last_elapsed_days: @last.scheduled_days,
          scheduled_days: @current.scheduled_days,
          learning_steps: @current.learning_steps,
          review: @review_time
        )
      end

      def next_ds(interval = 0)
        @algorithm.next_state(
          { difficulty: @last.difficulty, stability: @last.stability },
          interval,
          @current.state == State::NEW ? Rating::GOOD : @current.state
        )
      end

      def new_state(grade)
        raise NotImplementedError, "#{self.class} must implement #new_state"
      end

      def learning_state(grade)
        raise NotImplementedError, "#{self.class} must implement #learning_state"
      end

      def review_state(grade)
        raise NotImplementedError, "#{self.class} must implement #review_state"
      end
    end
  end
end
