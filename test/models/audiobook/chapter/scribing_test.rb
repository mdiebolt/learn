require "test_helper"

class Audiobook::Chapter::ScribingTest < ActiveSupport::TestCase
  # Chapter :two spans 60_000–180_000ms at position 1, so its Scribe word
  # timestamps (relative to the slice) must be offset by 60_000ms and its
  # word positions must sit in chapter 1's stride block.
  test "persist_words offsets timestamps by the chapter start and strides positions" do
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

    words = chapter.audiobook.transcript.words.between(60_000, 180_000).to_a
    base = 1 * Audiobook::Chapter::Scribing::WORD_POSITION_STRIDE
    assert_equal [ "I", "understand", "wonderful" ], words.map(&:text)
    assert_equal [ base, base + 1, base + 2 ], words.map(&:position)
    assert_equal [ 0, 3, 2 ], words.map(&:orp_index)
    assert_equal [ 60_000, 60_300, 60_900 ], words.map(&:start_time_ms)
    assert_equal [ 60_200, 60_900, 61_500 ], words.map(&:end_time_ms)
  end

  test "persist_words is idempotent over the chapter's own time slice" do
    chapter = audiobook_chapters(:two)
    response = { "words" => [ { "type" => "word", "text" => "again", "start" => 0.0, "end" => 0.4 } ] }

    chapter.send(:persist_words, response)
    chapter.send(:persist_words, response)

    words = chapter.audiobook.transcript.words.between(60_000, 180_000)
    assert_equal [ "again" ], words.map(&:text)
    # Chapter 1's fixture words (positions 0, 1) are outside this slice, untouched.
    assert_equal 2, chapter.audiobook.transcript.words.between(0, 60_000).count
  end
end
