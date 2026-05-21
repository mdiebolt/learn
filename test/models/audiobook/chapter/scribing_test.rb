require "test_helper"

class Audiobook::Chapter::ScribingTest < ActiveSupport::TestCase
  # Chapter :two spans 60_000–180_000ms at position 1, so its Scribe word
  # timestamps (relative to the slice) must be offset by 60_000ms.
  test "persist_words offsets timestamps by the chapter start" do
    chapter = audiobook_chapters(:two)
    response = {
      "words" => [
        { "type" => "word",    "text" => "I",          "start" => 0.0, "end" => 0.2 },
        { "type" => "spacing", "text" => " ",          "start" => 0.2, "end" => 0.3 },
        { "type" => "word",    "text" => "understand", "start" => 0.3, "end" => 0.9 },
        { "type" => "word",    "text" => "wonderful",  "start" => 0.9, "end" => 1.5 }
      ]
    }

    chapter.send(:persist_words, response)

    words = chapter.words.to_a
    assert_equal [ "I", "understand", "wonderful" ], words.map(&:text)
    assert_equal [ 0, 1, 2 ], words.map(&:position)
    assert_equal [ 0, 3, 2 ], words.map(&:orp_index)
    assert_equal [ 60_000, 60_300, 60_900 ], words.map(&:start_time_ms)
    assert_equal [ 60_200, 60_900, 61_500 ], words.map(&:end_time_ms)
  end

  test "persist_words is idempotent and only touches this chapter's words" do
    chapter = audiobook_chapters(:two)
    response = { "words" => [ { "type" => "word", "text" => "again", "start" => 0.0, "end" => 0.4 } ] }

    chapter.send(:persist_words, response)
    chapter.send(:persist_words, response)

    assert_equal [ "again" ], chapter.words.map(&:text)
    # Chapter :one's fixture words live in a different chapter, untouched.
    assert_equal 2, audiobook_chapters(:one).words.count
  end
end
