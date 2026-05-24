module FsrsRuby
  class ReviewLog
    attr_accessor :rating, :state, :due, :stability, :difficulty,
                  :elapsed_days, :last_elapsed_days, :scheduled_days,
                  :learning_steps, :review

    def initialize(
      rating:,
      state:,
      due:,
      stability:,
      difficulty:,
      elapsed_days:,
      last_elapsed_days:,
      scheduled_days:,
      learning_steps:,
      review:
    )
      @rating = rating
      @state = state
      @due = due
      @stability = stability.to_f
      @difficulty = difficulty.to_f
      @elapsed_days = elapsed_days
      @last_elapsed_days = last_elapsed_days
      @scheduled_days = scheduled_days
      @learning_steps = learning_steps
      @review = review
    end
  end
end
