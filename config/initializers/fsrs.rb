module Fsrs
  def self.instance
    @instance ||= FsrsRuby::FsrsInstance.new(request_retention: 0.9)
  end
end
