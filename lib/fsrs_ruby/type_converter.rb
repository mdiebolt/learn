# frozen_string_literal: true

module FsrsRuby
  # Type conversion utilities for normalizing inputs
  class TypeConverter
    # Convert various time formats to Time object
    # @param value [Time, Integer, String] Time value
    # @return [Time] Normalized Time object
    def self.time(value)
      case value
      when Time
        value
      when Integer
        Time.at(value)
      when String
        Time.parse(value)
      else
        raise ArgumentError, "Invalid time: #{value}"
      end
    end

    # Convert string or integer to State constant
    # @param value [Integer, String, Symbol] State value
    # @return [Integer] State constant
    def self.state(value)
      case value
      when Integer
        raise ArgumentError, "Invalid state: #{value}" unless State.valid?(value)
        value
      when String, Symbol
        State.from_string(value.to_s)
      else
        raise ArgumentError, "Invalid state: #{value}"
      end
    end

    # Convert string or integer to Rating constant
    # @param value [Integer, String, Symbol] Rating value
    # @return [Integer] Rating constant
    def self.rating(value)
      case value
      when Integer
        raise ArgumentError, "Invalid rating: #{value}" unless Rating.valid?(value)
        value
      when String, Symbol
        Rating.from_string(value.to_s)
      else
        raise ArgumentError, "Invalid rating: #{value}"
      end
    end

    # Normalize Card object
    # @param card_input [Card, Hash] Card or hash with card data
    # @return [Card] Normalized Card object
    def self.card(card_input)
      return card_input if card_input.is_a?(Card)

      Card.new(
        due: time(card_input[:due]),
        stability: card_input[:stability] || 0.0,
        difficulty: card_input[:difficulty] || 0.0,
        elapsed_days: card_input[:elapsed_days] || 0,
        scheduled_days: card_input[:scheduled_days] || 0,
        learning_steps: card_input[:learning_steps] || 0,
        reps: card_input[:reps] || 0,
        lapses: card_input[:lapses] || 0,
        state: state(card_input[:state] || State::NEW),
        last_review: card_input[:last_review] ? time(card_input[:last_review]) : nil
      )
    end
  end
end
