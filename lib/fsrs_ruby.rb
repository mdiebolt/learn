# frozen_string_literal: true

# Main FSRS Ruby module
module FsrsRuby
  class Error < StandardError; end
end

# Require all components in correct order
require_relative 'fsrs_ruby/version'
require_relative 'fsrs_ruby/constants'
require_relative 'fsrs_ruby/models'
require_relative 'fsrs_ruby/helpers'
require_relative 'fsrs_ruby/type_converter'
require_relative 'fsrs_ruby/alea'
require_relative 'fsrs_ruby/parameters'
require_relative 'fsrs_ruby/algorithm'
require_relative 'fsrs_ruby/strategies/learning_steps'
require_relative 'fsrs_ruby/strategies/seed'
require_relative 'fsrs_ruby/schedulers/base_scheduler'
require_relative 'fsrs_ruby/schedulers/basic_scheduler'
require_relative 'fsrs_ruby/schedulers/long_term_scheduler'
require_relative 'fsrs_ruby/fsrs_instance'

module FsrsRuby
  # Factory method to create FSRS instance
  # @param params [Hash] FSRS parameters
  # @return [FSRSInstance] FSRS instance
  def self.new(params = {})
    FSRSInstance.new(params)
  end

  # Create an empty card
  # @param now [Time, nil] Current time
  # @return [Card] New empty card
  def self.create_empty_card(now = nil)
    ParameterUtils.create_empty_card(now)
  end
end
