# frozen_string_literal: true

module FsrsRuby
  module Strategies
    # Default seed strategy using review time and card properties
    # @param scheduler [BaseScheduler] Scheduler instance
    # @return [String] Seed string
    def self.default_init_seed_strategy(scheduler)
      time = scheduler.review_time.to_i
      reps = scheduler.current.reps
      mul = (scheduler.current.difficulty * scheduler.current.stability).round(2)
      "#{time}_#{reps}_#{mul}"
    end

    # Generate seed strategy with card ID field
    # @param card_id_field [String, Symbol] Field name for card ID
    # @return [Proc] Seed strategy proc
    def self.gen_seed_strategy_with_card_id(card_id_field)
      ->(scheduler) do
        card_id = scheduler.current.send(card_id_field)
        reps = scheduler.current.reps || 0
        "#{card_id}#{reps}"
      end
    end
  end
end
