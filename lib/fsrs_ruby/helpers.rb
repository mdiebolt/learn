# frozen_string_literal: true

module FsrsRuby
  module Helpers
    def self.round8(value)
      return value if value.nil?
      (value * 100_000_000).round / 100_000_000.0
    end

    def self.clamp(value, min, max)
      [ [ value, min ].max, max ].min
    end

    # Add a time offset to a Time.
    # @param is_day [Boolean] If true, t is in days; if false, t is in minutes.
    def self.date_scheduler(now, t, is_day = false)
      if is_day
        now + (t * 24 * 60 * 60)
      else
        now + (t * 60)
      end
    end

    # Whole-day difference between two Times.
    def self.date_diff(now, pre)
      ((now - pre) / (24 * 60 * 60)).floor
    end

    def self.get_fuzz_range(interval, elapsed_days, maximum_interval)
      delta = 1.0

      if interval >= 2.5
        delta += (interval - 2.5) * 0.15 if interval < 7.0
        delta += (7.0 - 2.5) * 0.15 if interval >= 7.0
        delta += (interval - 7.0) * 0.10 if interval >= 7.0 && interval < 20.0
        delta += (20.0 - 7.0) * 0.10 if interval >= 20.0
        delta += (interval - 20.0) * 0.05 if interval >= 20.0
      end

      interval = [ interval, maximum_interval ].min

      min_ivl = [ 2, (interval - delta).round ].max
      max_ivl = [ (interval + delta).round, maximum_interval ].min

      min_ivl = [ min_ivl, elapsed_days + 1 ].max if interval > elapsed_days
      min_ivl = max_ivl if min_ivl > max_ivl

      { min_ivl: min_ivl, max_ivl: max_ivl }
    end
  end
end
