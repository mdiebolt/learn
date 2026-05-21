# frozen_string_literal: true

module FsrsRuby
  module Schedulers
    # Scheduler without short-term learning (no learning steps)
    class LongTermScheduler < BaseScheduler
      protected

      def new_state(grade)
        next_card = @current.clone

        state_result = @algorithm.next_state(
          { difficulty: 0, stability: 0 },
          0,
          grade
        )

        next_card.difficulty = state_result[:difficulty]
        next_card.stability = state_result[:stability]
        next_card.state = State::REVIEW
        next_card.learning_steps = 0

        interval = @algorithm.next_interval(next_card.stability, 0)
        next_card.scheduled_days = interval
        next_card.due = Helpers.date_scheduler(@review_time, interval, true)

        log = build_log(grade)
        RecordLogItem.new(card: next_card, log: log)
      end

      def learning_state(grade)
        # Treat learning as review
        review_state(grade)
      end

      def review_state(grade)
        interval = @elapsed_days
        next_card = @current.clone

        state_result = @algorithm.next_state(
          { difficulty: @last.difficulty, stability: @last.stability },
          interval,
          grade
        )

        next_card.difficulty = state_result[:difficulty]
        next_card.stability = state_result[:stability]
        next_card.state = State::REVIEW
        next_card.learning_steps = 0

        next_card.lapses += 1 if grade == Rating::AGAIN

        # Calculate intervals for all ratings using their respective stabilities
        intervals = [Rating::AGAIN, Rating::HARD, Rating::GOOD, Rating::EASY].map do |g|
          temp_state = @algorithm.next_state(
            { difficulty: @last.difficulty, stability: @last.stability },
            interval,
            g
          )
          @algorithm.next_interval(temp_state[:stability], interval)
        end

        # Ensure ordering only when necessary (don't artificially inflate intervals)
        # But respect maximum_interval - don't force intervals beyond it
        max_interval = @algorithm.parameters.maximum_interval
        intervals[0] = [intervals[0], intervals[1]].min # again <= hard
        if intervals[1] <= intervals[0] && intervals[0] < max_interval
          intervals[1] = [intervals[1], intervals[0] + 1].max
        end  # hard > again
        if intervals[2] <= intervals[1] && intervals[1] < max_interval
          intervals[2] = [intervals[2], intervals[1] + 1].max
        end  # good > hard
        if intervals[3] <= intervals[2] && intervals[2] < max_interval
          intervals[3] = [intervals[3], intervals[2] + 1].max
        end  # easy > good

        scheduled_days = intervals[[Rating::AGAIN, Rating::HARD, Rating::GOOD, Rating::EASY].index(grade)]
        next_card.scheduled_days = scheduled_days
        next_card.due = Helpers.date_scheduler(@review_time, scheduled_days, true)

        log = build_log(grade)
        RecordLogItem.new(card: next_card, log: log)
      end
    end
  end
end
