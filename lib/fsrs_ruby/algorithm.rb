# frozen_string_literal: true

module FsrsRuby
  # Core FSRS v6.0 algorithm implementation
  class Algorithm
    attr_reader :parameters, :interval_modifier
    attr_accessor :seed

    def initialize(params = {})
      @parameters = ParameterUtils.generate_parameters(params)
      @interval_modifier = calculate_interval_modifier(@parameters.request_retention)
      @seed = nil
    end

    # Update parameters and recalculate derived values
    def parameters=(params)
      @parameters = ParameterUtils.generate_parameters(params)
      @interval_modifier = calculate_interval_modifier(@parameters.request_retention)
    end

    # Compute decay factor from w[20]
    # @param w [Array<Float>, Float] Weights array or decay value
    # @return [Hash] { decay:, factor: }
    def compute_decay_factor(w)
      decay = w.is_a?(Array) ? -w[20] : -w
      factor = Math.exp(Math.log(0.9) / decay) - 1.0
      { decay: decay, factor: Helpers.round8(factor) }
    end

    # Forgetting curve formula
    # @param w [Array<Float>] Weights array
    # @param elapsed_days [Numeric] Days since last review
    # @param stability [Float] Stability (interval when R=90%)
    # @return [Float] Retrievability (probability of recall)
    def forgetting_curve(w, elapsed_days, stability)
      info = compute_decay_factor(w)
      result = (1 + (info[:factor] * elapsed_days) / stability)**info[:decay]
      Helpers.round8(result)
    end

    # Calculate interval modifier from request_retention
    # @param request_retention [Float] Target retention rate (0, 1]
    # @return [Float] Interval modifier
    def calculate_interval_modifier(request_retention)
      raise ArgumentError, 'Requested retention rate should be in the range (0,1]' if request_retention <= 0 || request_retention > 1

      info = compute_decay_factor(@parameters.w)
      Helpers.round8((request_retention**(1.0 / info[:decay]) - 1) / info[:factor])
    end

    # Initial stability (simple lookup)
    # @param g [Integer] Grade (1=Again, 2=Hard, 3=Good, 4=Easy)
    # @return [Float] Initial stability
    def init_stability(g)
      [@parameters.w[g - 1], Constants::S_MIN].max
    end

    # CRITICAL: Exponential difficulty formula (NOT linear!)
    # @param g [Integer] Grade (1=Again, 2=Hard, 3=Good, 4=Easy)
    # @return [Float] Initial difficulty (raw, not clamped)
    def init_difficulty(g)
      d = @parameters.w[4] - Math.exp((g - 1) * @parameters.w[5]) + 1
      Helpers.round8(d)
    end

    # NEW IN v6: Linear damping
    # @param delta_d [Float] Difficulty change
    # @param old_d [Float] Old difficulty
    # @return [Float] Damped difficulty change
    def linear_damping(delta_d, old_d)
      Helpers.round8((delta_d * (10 - old_d)) / 9.0)
    end

    # Mean reversion
    # @param init [Float] Initial difficulty
    # @param current [Float] Current difficulty
    # @return [Float] Reverted difficulty
    def mean_reversion(init, current)
      Helpers.round8(@parameters.w[7] * init + (1 - @parameters.w[7]) * current)
    end

    # Next difficulty with linear damping
    # @param d [Float] Current difficulty
    # @param g [Integer] Grade
    # @return [Float] Next difficulty [1, 10]
    def next_difficulty(d, g)
      delta_d = -@parameters.w[6] * (g - 3)
      next_d = d + linear_damping(delta_d, d)
      Helpers.clamp(mean_reversion(init_difficulty(Rating::EASY), next_d), 1, 10)
    end

    # Next recall stability (for successful reviews)
    # @param d [Float] Difficulty
    # @param s [Float] Stability
    # @param r [Float] Retrievability
    # @param g [Integer] Grade
    # @return [Float] New stability after recall
    def next_recall_stability(d, s, r, g)
      hard_penalty = g == Rating::HARD ? @parameters.w[15] : 1
      easy_bonus = g == Rating::EASY ? @parameters.w[16] : 1

      new_s = s * (
        1 + Math.exp(@parameters.w[8]) *
        (11 - d) *
        (s**-@parameters.w[9]) *
        (Math.exp((1 - r) * @parameters.w[10]) - 1) *
        hard_penalty *
        easy_bonus
      )

      Helpers.clamp(Helpers.round8(new_s), Constants::S_MIN, Constants::S_MAX)
    end

    # Next forget stability (for failed reviews)
    # @param d [Float] Difficulty
    # @param s [Float] Stability
    # @param r [Float] Retrievability
    # @return [Float] New stability after forgetting
    def next_forget_stability(d, s, r)
      new_s = (
        @parameters.w[11] *
        (d**-@parameters.w[12]) *
        ((s + 1)**@parameters.w[13] - 1) *
        Math.exp((1 - r) * @parameters.w[14])
      )

      Helpers.clamp(Helpers.round8(new_s), Constants::S_MIN, Constants::S_MAX)
    end

    # NEW IN v6: Short-term stability
    # @param s [Float] Stability
    # @param g [Integer] Grade
    # @return [Float] New short-term stability
    def next_short_term_stability(s, g)
      sinc = (s**-@parameters.w[19]) * Math.exp(@parameters.w[17] * (g - 3 + @parameters.w[18]))

      masked_sinc = g >= Rating::HARD ? [sinc, 1.0].max : sinc
      Helpers.clamp(Helpers.round8(s * masked_sinc), Constants::S_MIN, Constants::S_MAX)
    end

    # Apply fuzz using Alea PRNG
    # @param ivl [Numeric] Interval
    # @param elapsed_days [Integer] Days since last review
    # @return [Integer] Fuzzed interval
    def apply_fuzz(ivl, elapsed_days)
      return ivl.round unless @parameters.enable_fuzz && ivl >= 2.5

      prng = @seed ? FsrsRuby.alea(@seed) : FsrsRuby.alea(Time.now.to_i)
      fuzz_factor = prng.call

      fuzz_range = Helpers.get_fuzz_range(ivl, elapsed_days, @parameters.maximum_interval)
      (fuzz_factor * (fuzz_range[:max_ivl] - fuzz_range[:min_ivl] + 1) + fuzz_range[:min_ivl]).floor
    end

    # Calculate next interval
    # @param s [Float] Stability
    # @param elapsed_days [Integer] Days since last review
    # @return [Integer] Next interval in days
    def next_interval(s, elapsed_days = 0)
      new_interval = [(s * @interval_modifier).round, 1].max
      new_interval = [new_interval, @parameters.maximum_interval].min
      apply_fuzz(new_interval, elapsed_days)
    end

    # Calculate next state of memory
    # @param memory_state [Hash, nil] Current state { difficulty:, stability: } or nil
    # @param t [Numeric] Time elapsed since last review
    # @param g [Integer] Grade (0=Manual, 1=Again, 2=Hard, 3=Good, 4=Easy)
    # @param r [Float, nil] Optional retrievability value
    # @return [Hash] { difficulty:, stability: }
    def next_state(memory_state, t, g, r = nil)
      d = memory_state ? memory_state[:difficulty] : 0
      s = memory_state ? memory_state[:stability] : 0

      raise ArgumentError, "Invalid delta_t \"#{t}\"" if t < 0
      raise ArgumentError, "Invalid grade \"#{g}\"" if g < 0 || g > 4

      # First review
      if d == 0 && s == 0
        return {
          difficulty: Helpers.clamp(init_difficulty(g), 1, 10),
          stability: init_stability(g)
        }
      end

      # Manual grade
      if g == 0
        return { difficulty: d, stability: s }
      end

      # Validate state
      if d < 1 || s < Constants::S_MIN
        raise ArgumentError, "Invalid memory state { difficulty: #{d}, stability: #{s} }"
      end

      # Calculate retrievability if not provided
      r = forgetting_curve(@parameters.w, t, s) if r.nil?

      # Calculate possible next stabilities
      s_after_success = next_recall_stability(d, s, r, g)
      s_after_fail = next_forget_stability(d, s, r)
      s_after_short_term = next_short_term_stability(s, g)

      # Select appropriate stability
      new_s = s_after_success

      if g == Rating::AGAIN
        w_17 = @parameters.enable_short_term ? @parameters.w[17] : 0
        w_18 = @parameters.enable_short_term ? @parameters.w[18] : 0
        next_s_min = s / Math.exp(w_17 * w_18)
        new_s = Helpers.clamp(Helpers.round8(next_s_min), Constants::S_MIN, s_after_fail)
      end

      if t == 0 && @parameters.enable_short_term
        new_s = s_after_short_term
      end

      new_d = next_difficulty(d, g)
      { difficulty: new_d, stability: new_s }
    end
  end
end
