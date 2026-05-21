# frozen_string_literal: true

# A port of Alea algorithm by Johannes Baagøe
# https://github.com/davidbau/seedrandom/blob/released/lib/alea.js
# Original work is under MIT license

module FsrsRuby
  # Mash hash function for Alea PRNG
  class Mash
    def initialize
      @n = 0xefc8249d
    end

    def call(data)
      data = data.to_s
      data.each_char do |char|
        @n += char.ord
        h = 0.02519603282416938 * @n
        @n = h.to_i & 0xffffffff  # >>> 0 equivalent
        h -= @n
        h *= @n
        @n = h.to_i & 0xffffffff  # >>> 0 equivalent
        h -= @n
        @n += (h * 0x100000000).to_i  # 2^32
      end
      (@n & 0xffffffff) * 2.3283064365386963e-10  # 2^-32
    end
  end

  # Alea PRNG class
  class Alea
    attr_accessor :c, :s0, :s1, :s2

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
      t = 2091639 * @s0 + @c * 2.3283064365386963e-10  # 2^-32
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

  # Factory function for creating Alea PRNG with callable interface
  # @param seed [Integer, String, nil] Seed for PRNG
  # @return [Proc] Callable PRNG with additional methods
  def self.alea(seed = nil)
    xg = Alea.new(seed)

    prng = lambda { xg.next }

    # Add methods to the proc
    prng.define_singleton_method(:int32) do
      (xg.next * 0x100000000).to_i
    end

    prng.define_singleton_method(:double) do
      prng.call + ((prng.call * 0x200000).to_i * 1.1102230246251565e-16)  # 2^-53
    end

    prng.define_singleton_method(:state) do
      xg.state
    end

    prng.define_singleton_method(:import_state) do |state|
      xg.state = state
      prng
    end

    prng
  end
end
