require "test_helper"

class Audiobook::ChapterTest < ActiveSupport::TestCase
  test "duration_ms is the difference between end and start" do
    chapter = audiobook_chapters(:one)
    assert_equal 60_000, chapter.duration_ms
  end

  test "default scope orders by position" do
    audiobook = audiobooks(:one)
    assert_equal [0, 1], audiobook.chapters.map(&:position)
  end
end
