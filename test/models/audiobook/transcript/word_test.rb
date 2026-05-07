require "test_helper"

class Audiobook::Transcript::WordTest < ActiveSupport::TestCase
  test "covering scope finds the word at a given timestamp" do
    transcript = audiobook_transcripts(:one)
    word = transcript.words.covering(250).first

    assert_equal "Hello", word.text
  end

  test "covering scope returns the next word right at a boundary" do
    transcript = audiobook_transcripts(:one)
    word = transcript.words.covering(500).first

    # 500ms is the start of "world" (and the end of "Hello"); end_time_ms is
    # exclusive so the boundary belongs to the next word.
    assert_equal "world", word.text
  end
end
