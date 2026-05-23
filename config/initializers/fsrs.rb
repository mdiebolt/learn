module Fsrs
  def self.instance
    FsrsRuby::FsrsInstance.new(request_retention: 0.9)
  end
end
