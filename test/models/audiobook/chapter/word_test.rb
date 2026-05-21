require "test_helper"

class Audiobook::Chapter::WordTest < ActiveSupport::TestCase
  test "covering scope finds the word at a given timestamp" do
    chapter = audiobook_chapters(:one)
    word = chapter.words.covering(250).first

    assert_equal "Hello", word.text
  end

  test "covering scope returns the next word right at a boundary" do
    chapter = audiobook_chapters(:one)
    word = chapter.words.covering(500).first

    # 500ms is the start of "world" (and the end of "Hello"); end_time_ms is
    # exclusive so the boundary belongs to the next word.
    assert_equal "world", word.text
  end
end
