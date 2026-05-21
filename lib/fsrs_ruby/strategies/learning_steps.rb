# frozen_string_literal: true

module FsrsRuby
  module Strategies
    # Convert step unit string to minutes
    # @param step [String] Step string like "1m", "10m", "5h", "2d"
    # @return [Integer] Minutes
    def self.convert_step_unit_to_minutes(step)
      unit = step[-1]
      value = step[0...-1].to_i

      raise ArgumentError, "Invalid step value: #{step}" if value < 0

      case unit
      when 'm'
        value
      when 'h'
        value * 60
      when 'd'
        value * 1440
      else
        raise ArgumentError, "Invalid step unit: #{step}, expected m/h/d"
      end
    end

    # Basic learning steps strategy
    # @param parameters [Parameters] FSRS parameters
    # @param state [Integer] Current state
    # @param cur_step [Integer] Current step index
    # @return [Hash] Mapping of ratings to { scheduled_minutes:, next_step: }
    def self.basic_learning_steps_strategy(parameters, state, cur_step)
      learning_steps = if [State::RELEARNING, State::REVIEW].include?(state)
                         parameters.relearning_steps
                       else
                         parameters.learning_steps
                       end

      steps_length = learning_steps.length
      return {} if steps_length.zero? || cur_step >= steps_length

      first_step = learning_steps[0]

      result = {}

      if state == State::REVIEW
        # Review → again: return first relearning step
        result[Rating::AGAIN] = {
          scheduled_minutes: convert_step_unit_to_minutes(first_step),
          next_step: 0
        }
      else
        # New, Learning, Relearning states
        result[Rating::AGAIN] = {
          scheduled_minutes: convert_step_unit_to_minutes(first_step),
          next_step: 0
        }

        # Hard interval
        hard_minutes = if steps_length == 1
                         (convert_step_unit_to_minutes(first_step) * 1.5).round
                       else
                         second_step = learning_steps[1]
                         ((convert_step_unit_to_minutes(first_step) + convert_step_unit_to_minutes(second_step)) / 2.0).round
                       end

        result[Rating::HARD] = {
          scheduled_minutes: hard_minutes,
          next_step: cur_step
        }

        # Good: advance to next step if it exists
        next_step_index = cur_step + 1
        if next_step_index < steps_length
          next_step = learning_steps[next_step_index]
          result[Rating::GOOD] = {
            scheduled_minutes: convert_step_unit_to_minutes(next_step).round,
            next_step: next_step_index
          }
        end
      end

      result
    end
  end
end
