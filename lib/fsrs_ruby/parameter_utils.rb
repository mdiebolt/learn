# frozen_string_literal: true

module FsrsRuby
  module ParameterUtils
    # Clip parameters to valid ranges.
    def self.clip_parameters(parameters, num_relearning_steps, enable_short_term = true)
      w17_w18_ceiling = Constants::W17_W18_CEILING

      if [ num_relearning_steps, 0 ].max > 1
        value = -(
          Math.log(parameters[11]) +
          Math.log(2.0**parameters[13] - 1.0) +
          parameters[14] * 0.3
        ) / num_relearning_steps

        w17_w18_ceiling = Helpers.clamp(Helpers.round8(value), 0.01, 2.0)
      end

      clamp_ranges = Constants.clamp_parameters(w17_w18_ceiling, enable_short_term)
      clamp_ranges = clamp_ranges.slice(0, parameters.length)

      clamp_ranges.each_with_index.map do |(min, max), index|
        Helpers.clamp(parameters[index] || 0, min, max)
      end
    end

    def self.generate_parameters(props = {})
      learning_steps = props[:learning_steps] || Constants::DEFAULT_LEARNING_STEPS.dup
      relearning_steps = props[:relearning_steps] || Constants::DEFAULT_RELEARNING_STEPS.dup
      enable_short_term = props.key?(:enable_short_term) ? props[:enable_short_term] : Constants::DEFAULT_ENABLE_SHORT_TERM

      w = if props[:w]
            clip_parameters(props[:w].dup, relearning_steps.length, enable_short_term)
      else
            Constants::DEFAULT_WEIGHTS.dup
      end

      Parameters.new(
        request_retention: props[:request_retention] || Constants::DEFAULT_REQUEST_RETENTION,
        maximum_interval: props[:maximum_interval] || Constants::DEFAULT_MAXIMUM_INTERVAL,
        w: w,
        enable_fuzz: props.key?(:enable_fuzz) ? props[:enable_fuzz] : Constants::DEFAULT_ENABLE_FUZZ,
        enable_short_term: enable_short_term,
        learning_steps: learning_steps,
        relearning_steps: relearning_steps
      )
    end

    def self.create_empty_card(now = nil)
      now ||= Time.now

      Card.new(
        due: now,
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
    end
  end
end
