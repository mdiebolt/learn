# frozen_string_literal: true

module FsrsRuby
  module ParameterUtils
    # Clip parameters to valid ranges
    # @param parameters [Array<Numeric>] Parameter array
    # @param num_relearning_steps [Integer] Number of relearning steps
    # @param enable_short_term [Boolean] Whether short-term learning is enabled
    # @return [Array<Float>] Clipped parameters
    def self.clip_parameters(parameters, num_relearning_steps, enable_short_term = true)
      w17_w18_ceiling = Constants::W17_W18_CEILING

      if [num_relearning_steps, 0].max > 1
        # Calculate ceiling: w17 * w18 <= -[ln(w11) + ln(2^w13 - 1) + w14*0.3] / num_relearning_steps
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

    # Check if parameters are valid
    # @param parameters [Array<Numeric>] Parameter array
    # @return [Array<Numeric>] Same array if valid
    # @raise [ArgumentError] If parameters are invalid
    def self.check_parameters(parameters)
      invalid = parameters.find { |param| !param.is_a?(Numeric) || !param.finite? }
      if invalid
        raise ArgumentError, "Non-finite or NaN value in parameters: #{parameters}"
      elsif ![17, 19, 21].include?(parameters.length)
        raise ArgumentError,
              "Invalid parameter length: #{parameters.length}. Must be 17, 19 or 21 for FSRSv4, 5 and 6 respectively."
      end

      parameters
    end

    # Migrate parameters from v4/v5 to v6 format
    # @param parameters [Array<Numeric>, nil] Parameter array
    # @param num_relearning_steps [Integer] Number of relearning steps
    # @param enable_short_term [Boolean] Whether short-term learning is enabled
    # @return [Array<Float>] Migrated parameters (always 21 elements)
    def self.migrate_parameters(parameters = nil, num_relearning_steps = 0, enable_short_term = true)
      return Constants::DEFAULT_WEIGHTS.dup if parameters.nil?

      case parameters.length
      when 21
        # v6: Just clip
        clip_parameters(parameters.dup, num_relearning_steps, enable_short_term)
      when 19
        # v5: Clip and append [0.0, FSRS5_DEFAULT_DECAY]
        warn '[FSRS-6] Auto fill w from 19 to 21 length'
        clipped = clip_parameters(parameters.dup, num_relearning_steps, enable_short_term)
        clipped + [0.0, Constants::FSRS5_DEFAULT_DECAY]
      when 17
        # v4: Clip, transform w[4], w[5], w[6], then append [0.0, 0.0, 0.0, FSRS5_DEFAULT_DECAY]
        w = clip_parameters(parameters.dup, num_relearning_steps, enable_short_term)

        # Transform parameters for v6
        w[4] = Helpers.round8(w[5] * 2.0 + w[4])
        w[5] = Helpers.round8(Math.log(w[5] * 3.0 + 1.0) / 3.0)
        w[6] = Helpers.round8(w[6] + 0.5)

        warn '[FSRS-6] Auto fill w from 17 to 21 length'
        w + [0.0, 0.0, 0.0, Constants::FSRS5_DEFAULT_DECAY]
      else
        # Invalid length, use defaults
        warn '[FSRS] Invalid parameters length, using default parameters'
        Constants::DEFAULT_WEIGHTS.dup
      end
    end

    # Generate FSRS parameters from partial input
    # @param props [Hash] Partial parameters
    # @return [Parameters] Complete parameters object
    def self.generate_parameters(props = {})
      learning_steps = props[:learning_steps] || Constants::DEFAULT_LEARNING_STEPS.dup
      relearning_steps = props[:relearning_steps] || Constants::DEFAULT_RELEARNING_STEPS.dup
      enable_short_term = props.key?(:enable_short_term) ? props[:enable_short_term] : Constants::DEFAULT_ENABLE_SHORT_TERM

      w = migrate_parameters(
        props[:w],
        relearning_steps.length,
        enable_short_term
      )

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

    # Create an empty card
    # @param now [Time, nil] Current time (defaults to Time.now)
    # @return [Card] New empty card
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
