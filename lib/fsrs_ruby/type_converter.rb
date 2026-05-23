# frozen_string_literal: true

module FsrsRuby
  class TypeConverter
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
        state: card_input[:state] || State::NEW,
        last_review: card_input[:last_review] ? time(card_input[:last_review]) : nil
      )
    end
  end
end
