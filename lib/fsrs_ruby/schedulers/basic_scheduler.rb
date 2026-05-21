# frozen_string_literal: true

module FsrsRuby
  module Schedulers
    # Scheduler with short-term learning support
    class BasicScheduler < BaseScheduler
      def initialize(card, now, algorithm, strategies = {})
        super
        @learning_steps_strategy = strategies[:learning_steps] || method(:default_learning_steps)
      end

      protected

      def default_learning_steps(parameters, state, cur_step)
        Strategies.basic_learning_steps_strategy(parameters, state, cur_step)
      end

      # Get learning step info for current card and grade
      def get_learning_info(card, grade)
        @learning_steps_strategy.call(@algorithm.parameters, card.state, card.learning_steps || 0)[grade]
      end

      # Apply learning steps to next card
      def apply_learning_steps(next_card, grade, to_state)
        step_info = get_learning_info(@current, grade)

        if step_info
          scheduled_minutes = step_info[:scheduled_minutes]
          next_steps = step_info[:next_step]

          if scheduled_minutes > 0 && scheduled_minutes < 1440
            # Schedule by minutes, stay in learning state
            next_card.learning_steps = next_steps
            next_card.scheduled_days = 0
            next_card.state = to_state
            next_card.due = Helpers.date_scheduler(@review_time, scheduled_minutes, false)
          elsif scheduled_minutes >= 1440
            # Promote to REVIEW, schedule by days
            next_card.state = State::REVIEW
            scheduled_days = (scheduled_minutes / 1440.0).round
            next_card.scheduled_days = scheduled_days
            next_card.due = Helpers.date_scheduler(@review_time, scheduled_days, true)
            next_card.learning_steps = 0
          else
            # Negative or zero: promote to REVIEW with full interval
            next_card.state = State::REVIEW
            interval = @algorithm.next_interval(next_card.stability, @elapsed_days)
            next_card.scheduled_days = interval
            next_card.due = Helpers.date_scheduler(@review_time, interval, true)
            next_card.learning_steps = 0
          end
        else
          # No step info: promote to REVIEW
          next_card.state = State::REVIEW
          interval = @algorithm.next_interval(next_card.stability, @elapsed_days)
          next_card.scheduled_days = interval
          next_card.due = Helpers.date_scheduler(@review_time, interval, true)
          next_card.learning_steps = 0
        end
      end

      def new_state(grade)
        next_card = @current.clone
        state_result = @algorithm.next_state(
          { difficulty: 0, stability: 0 },
          0,
          grade
        )

        next_card.difficulty = state_result[:difficulty]
        next_card.stability = state_result[:stability]

        apply_learning_steps(next_card, grade, State::LEARNING)

        log = build_log(grade)
        RecordLogItem.new(card: next_card, log: log)
      end

      def learning_state(grade)
        next_card = @current.clone
        interval = @elapsed_days

        state_result = @algorithm.next_state(
          { difficulty: @last.difficulty, stability: @last.stability },
          interval,
          grade
        )

        next_card.difficulty = state_result[:difficulty]
        next_card.stability = state_result[:stability]

        to_state = @current.state == State::RELEARNING ? State::RELEARNING : State::LEARNING

        if [Rating::AGAIN, Rating::HARD].include?(grade)
          to_state = @current.state == State::RELEARNING ? State::RELEARNING : State::LEARNING
        end

        apply_learning_steps(next_card, grade, to_state)

        log = build_log(grade)
        RecordLogItem.new(card: next_card, log: log)
      end

      def review_state(grade)
        interval = @elapsed_days
        retrievability = @algorithm.forgetting_curve(@algorithm.parameters.w, interval, @last.stability)

        next_card = @current.clone

        state_result = @algorithm.next_state(
          { difficulty: @last.difficulty, stability: @last.stability },
          interval,
          grade
        )

        next_card.difficulty = state_result[:difficulty]
        next_card.stability = state_result[:stability]

        if grade == Rating::AGAIN
          next_card.lapses += 1
          apply_learning_steps(next_card, grade, State::RELEARNING)
        else
          # Hard, Good, Easy: stay in REVIEW
          next_card.state = State::REVIEW
          next_card.learning_steps = 0

          # Calculate stability for HARD rating to get correct hard_interval
          hard_state = @algorithm.next_state(
            { difficulty: @last.difficulty, stability: @last.stability },
            interval,
            Rating::HARD
          )
          hard_interval = @algorithm.next_interval(hard_state[:stability], interval)

          # Calculate different intervals for each grade
          if grade == Rating::HARD
            next_card.scheduled_days = hard_interval
          elsif grade == Rating::GOOD
            good_interval = @algorithm.next_interval(next_card.stability, interval)
            # Only enforce ordering if intervals would violate it and we're not at max_interval
            if good_interval <= hard_interval && hard_interval < @algorithm.parameters.maximum_interval
              good_interval = [good_interval, hard_interval + 1].max
            end
            next_card.scheduled_days = good_interval
          else # EASY
            good_state = @algorithm.next_state(
              { difficulty: @last.difficulty, stability: @last.stability },
              interval,
              Rating::GOOD
            )
            good_interval = @algorithm.next_interval(good_state[:stability], interval)

            easy_state = @algorithm.next_state(
              { difficulty: @last.difficulty, stability: @last.stability },
              interval,
              Rating::EASY
            )
            easy_interval = @algorithm.next_interval(easy_state[:stability], interval)
            # Only enforce ordering if intervals would violate it and we're not at max_interval
            if easy_interval <= good_interval && good_interval < @algorithm.parameters.maximum_interval
              easy_interval = [easy_interval, good_interval + 1].max
            end
            next_card.scheduled_days = easy_interval
          end

          next_card.due = Helpers.date_scheduler(@review_time, next_card.scheduled_days, true)
        end

        log = build_log(grade)
        RecordLogItem.new(card: next_card, log: log)
      end
    end
  end
end
