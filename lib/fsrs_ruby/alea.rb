# frozen_string_literal: true

# A port of Alea algorithm by Johannes Baagøe
# https://github.com/davidbau/seedrandom/blob/released/lib/alea.js
# Original work is under MIT license

module FsrsRuby
  class Alea
    attr_accessor :c, :s0, :s1, :s2

    # Returns a lambda that yields the next pseudo-random value on each call.
    # Wraps an Alea instance so callers can pass `prng.call` rather than
    # tracking the instance themselves.
    def self.factory(seed = nil)
      xg = new(seed)

      prng = lambda { xg.next }

      prng.define_singleton_method(:int32) { (xg.next * 0x100000000).to_i }
      prng.define_singleton_method(:double) { prng.call + ((prng.call * 0x200000).to_i * 1.1102230246251565e-16) }
      prng.define_singleton_method(:state) { xg.state }
      prng.define_singleton_method(:import_state) { |state| xg.state = state; prng }

      prng
    end

    def initialize(seed = nil)
      mash = Mash.new
      @c = 1
      @s0 = mash.call(' ')
      @s1 = mash.call(' ')
      @s2 = mash.call(' ')

      seed = Time.now.to_i if seed.nil?

      @s0 -= mash.call(seed)
      @s0 += 1 if @s0 < 0

      @s1 -= mash.call(seed)
      @s1 += 1 if @s1 < 0

      @s2 -= mash.call(seed)
      @s2 += 1 if @s2 < 0
    end

    def next
      t = 2091639 * @s0 + @c * 2.3283064365386963e-10
      @s0 = @s1
      @s1 = @s2
      @c = t.to_i
      @s2 = t - @c
      @s2
    end

    def state
      { c: @c, s0: @s0, s1: @s1, s2: @s2 }
    end

    def state=(new_state)
      @c = new_state[:c]
      @s0 = new_state[:s0]
      @s1 = new_state[:s1]
      @s2 = new_state[:s2]
    end
  end
end
