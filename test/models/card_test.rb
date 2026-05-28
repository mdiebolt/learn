require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup { @card = cards(:new) }

  test "review! creates a review row snapshotting the prior FSRS columns" do
    prior = @card.slice(:state, :due, :stability, :difficulty, :elapsed_days)

    assert_difference -> { @card.reviews.count }, 1 do
      @card.review!(rating: FsrsRuby::Rating::GOOD)
    end

    review = @card.reviews.last
    assert_equal prior["state"], review.prior_state
    assert_equal prior["due"], review.prior_due
    assert_equal prior["stability"], review.prior_stability
    assert_equal prior["difficulty"], review.prior_difficulty
    assert_equal prior["elapsed_days"], review.prior_elapsed_days
    assert_equal FsrsRuby::Rating::GOOD, review.rating
  end

  test "review! advances the card out of NEW and forward in time" do
    now = Time.current
    assert_equal FsrsRuby::State::NEW, @card.state

    @card.review!(rating: FsrsRuby::Rating::GOOD, now:)
    @card.reload

    assert_not_equal FsrsRuby::State::NEW, @card.state
    assert_operator @card.stability, :>, 0.0
    assert_operator @card.due, :>=, now
    assert_in_delta now.to_f, @card.last_review.to_f, 1.0
  end

  test "review! persists the optional response payload" do
    @card.review!(rating: FsrsRuby::Rating::HARD, response: { "picked" => 2 })

    assert_equal({ "picked" => 2 }, @card.reviews.last.response)
  end

  test "review! is atomic — a failed update! rolls back the review insert" do
    @card.define_singleton_method(:update!) { |*| raise ActiveRecord::RecordInvalid.new(self) }

    assert_no_difference -> { @card.reviews.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        @card.review!(rating: FsrsRuby::Rating::GOOD)
      end
    end
  end
end
