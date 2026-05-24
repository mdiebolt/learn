module FsrsRuby
  class Parameters
    attr_accessor :request_retention, :maximum_interval, :w, :enable_fuzz,
                  :enable_short_term, :learning_steps, :relearning_steps

    def initialize(
      request_retention: Constants::DEFAULT_REQUEST_RETENTION,
      maximum_interval: Constants::DEFAULT_MAXIMUM_INTERVAL,
      w: Constants::DEFAULT_WEIGHTS.dup,
      enable_fuzz: Constants::DEFAULT_ENABLE_FUZZ,
      enable_short_term: Constants::DEFAULT_ENABLE_SHORT_TERM,
      learning_steps: Constants::DEFAULT_LEARNING_STEPS.dup,
      relearning_steps: Constants::DEFAULT_RELEARNING_STEPS.dup
    )
      @request_retention = request_retention
      @maximum_interval = maximum_interval
      @w = w
      @enable_fuzz = enable_fuzz
      @enable_short_term = enable_short_term
      @learning_steps = learning_steps
      @relearning_steps = relearning_steps
    end
  end
end
