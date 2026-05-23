# frozen_string_literal: true

# A port of Alea algorithm by Johannes Baagøe
# https://github.com/davidbau/seedrandom/blob/released/lib/alea.js
# Original work is under MIT license

module FsrsRuby
  class Mash
    def initialize
      @n = 0xefc8249d
    end

    def call(data)
      data = data.to_s
      data.each_char do |char|
        @n += char.ord
        h = 0.02519603282416938 * @n
        @n = h.to_i & 0xffffffff
        h -= @n
        h *= @n
        @n = h.to_i & 0xffffffff
        h -= @n
        @n += (h * 0x100000000).to_i
      end
      (@n & 0xffffffff) * 2.3283064365386963e-10
    end
  end
end
