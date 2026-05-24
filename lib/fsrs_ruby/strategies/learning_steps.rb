module FsrsRuby
  module Strategies
    class LearningSteps
      def self.call(parameters, state, cur_step)
        learning_steps = if [ State::RELEARNING, State::REVIEW ].include?(state)
                          parameters.relearning_steps
        else
                          parameters.learning_steps
        end

        steps_length = learning_steps.length
        return {} if steps_length.zero? || cur_step >= steps_length

        first_step = learning_steps[0]
        result = {}

        if state == State::REVIEW
          result[Rating::AGAIN] = {
            scheduled_minutes: convert_step_unit_to_minutes(first_step),
            next_step: 0
          }
        else
          result[Rating::AGAIN] = {
            scheduled_minutes: convert_step_unit_to_minutes(first_step),
            next_step: 0
          }

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

      def self.convert_step_unit_to_minutes(step)
        unit = step[-1]
        value = step[0...-1].to_i

        raise ArgumentError, "Invalid step value: #{step}" if value < 0

        case unit
        when "m" then value
        when "h" then value * 60
        when "d" then value * 1_440
        else
          raise ArgumentError, "Invalid step unit: #{step}, expected m/h/d"
        end
      end
    end
  end
end
