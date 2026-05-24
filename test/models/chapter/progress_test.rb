require "test_helper"

class Chapter::ProgressTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @chapter = chapters(:one)
    @progress = @user.chapter_progresses.find_or_initialize_by(chapter: @chapter)
  end

  test "record persists progress_ms without marking completed" do
    assert @progress.record(progress_params(progress_ms: 1_234))
    assert_equal 1_234, @progress.reload.progress_ms
    assert_nil @progress.completed_at
    assert_not @progress.completed?
  end

  test "record stamps completed_at when completed is truthy" do
    freeze_time = Time.utc(2026, 5, 24, 12)
    travel_to freeze_time do
      assert @progress.record(progress_params(progress_ms: 60_000, completed: true))
    end

    @progress.reload
    assert_equal 60_000, @progress.progress_ms
    assert_equal freeze_time, @progress.completed_at
    assert @progress.completed?
  end

  test "record does not reset completed_at on a later progress-only save" do
    original = Time.utc(2026, 5, 24, 12)
    travel_to(original) { @progress.record(progress_params(progress_ms: 60_000, completed: true)) }

    travel_to(original + 1.hour) { @progress.record(progress_params(progress_ms: 70_000)) }

    @progress.reload
    assert_equal 70_000, @progress.progress_ms
    assert_equal original, @progress.completed_at
  end

  private
    def progress_params(**attrs)
      ActionController::Parameters.new(attrs).permit(:progress_ms, :completed)
    end
end
