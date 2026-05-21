require "fsrs_ruby"

module Fsrs
  def self.instance
    @instance ||= FsrsRuby.new(request_retention: 0.9)
  end
end
