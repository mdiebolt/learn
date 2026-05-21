# frozen_string_literal: true

module FsrsRuby
  module Helpers
    # Round to 8 decimal places for TypeScript compatibility
    def self.round8(value)
      return value if value.nil?
      (value * 100_000_000).round / 100_000_000.0
    end

    # Clamp value between min and max
    def self.clamp(value, min, max)
      [[value, min].max, max].min
    end

    # Add time offset to a date
    # @param now [Time] Current time
    # @param t [Numeric] Time offset value
    # @param is_day [Boolean] If true, t is in days; if false, t is in minutes
    # @return [Time] New time with offset applied
    def self.date_scheduler(now, t, is_day = false)
      if is_day
        now + (t * 24 * 60 * 60)  # Days to seconds
      else
        now + (t * 60)  # Minutes to seconds
      end
    end

    # Calculate difference between two dates
    # @param now [Time] Current time
    # @param pre [Time] Previous time
    # @param unit [Symbol] :days or :minutes
    # @return [Integer] Difference in specified units
    def self.date_diff(now, pre, unit)
      diff_seconds = now - pre

      case unit
      when :days
        (diff_seconds / (24 * 60 * 60)).floor
      when :minutes
        (diff_seconds / 60).floor
      else
        raise ArgumentError, "Invalid unit: #{unit}. Use :days or :minutes"
      end
    end

    # Calculate fuzz range for interval randomization
    # @param interval [Numeric] Base interval
    # @param elapsed_days [Integer] Days since last review
    # @param maximum_interval [Integer] Maximum allowed interval
    # @return [Hash] { min_ivl:, max_ivl: }
    def self.get_fuzz_range(interval, elapsed_days, maximum_interval)
      delta = 1.0

      # Apply fuzzing factors based on interval ranges
      if interval >= 2.5
        delta += (interval - 2.5) * 0.15 if interval < 7.0
        delta += (7.0 - 2.5) * 0.15 if interval >= 7.0
        delta += (interval - 7.0) * 0.10 if interval >= 7.0 && interval < 20.0
        delta += (20.0 - 7.0) * 0.10 if interval >= 20.0
        delta += (interval - 20.0) * 0.05 if interval >= 20.0
      end

      # Clamp interval to maximum
      interval = [interval, maximum_interval].min

      min_ivl = [2, (interval - delta).round].max
      max_ivl = [(interval + delta).round, maximum_interval].min

      # Ensure min_ivl is greater than elapsed_days if interval exceeds it
      min_ivl = [min_ivl, elapsed_days + 1].max if interval > elapsed_days

      # Ensure min <= max
      min_ivl = max_ivl if min_ivl > max_ivl

      { min_ivl: min_ivl, max_ivl: max_ivl }
    end

    # Format date as YYYY-MM-DD HH:MM:SS
    # @param time [Time] Time object
    # @return [String] Formatted date string
    def self.format_date(time)
      time.strftime('%Y-%m-%d %H:%M:%S')
    end

    # Calculate day difference ignoring time
    # @param last [Time] Last review time
    # @param cur [Time] Current time
    # @return [Integer] Day difference
    def self.date_diff_in_days(last, cur)
      (cur.to_date - last.to_date).to_i
    end
  end
end
