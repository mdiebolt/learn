require "test_helper"

class Audiobook::TranscriptTest < ActiveSupport::TestCase
  test "default status is pending" do
    assert audiobook_transcripts(:one).pending?
  end

  test "Scribing#populate_from_scribe! is a no-op when words exist and force is false" do
    transcript = audiobook_transcripts(:one)
    # The fixture has 2 words attached.
    refute transcript.words.empty?

    # If we got here without raising, the early return worked. We never
    # touched ElevenLabs::Scribe (which would have raised on missing key).
    assert_nothing_raised do
      transcript.populate_from_scribe!(force: false)
    end
  end

  test "persist_response bulk-inserts words with computed ORP and reports progress" do
    transcript = audiobook_transcripts(:one)
    response = {
      "words" => [
        { "type" => "word",     "text" => "I",           "start" => 0.0,  "end" => 0.2 },
        { "type" => "spacing",  "text" => " ",           "start" => 0.2,  "end" => 0.3 },
        { "type" => "word",     "text" => "understand",  "start" => 0.3,  "end" => 0.9 },
        { "type" => "word",     "text" => "wonderful",   "start" => 0.9,  "end" => 1.5 }
      ]
    }

    transcript.send(:persist_response, response)

    words = transcript.words.reload.to_a
    assert_equal [ "I", "understand", "wonderful" ], words.map(&:text)
    assert_equal [ 0, 1, 2 ], words.map(&:position)
    # 1-letter → 0, 10-letter → 3, 9-letter → 2
    assert_equal [ 0, 3, 2 ], words.map(&:orp_index)
    assert_equal [ 0, 300, 900 ], words.map(&:start_time_ms)
    assert_equal [ 200, 900, 1500 ], words.map(&:end_time_ms)
    assert_equal "Saving 3 of 3 words…", transcript.reload.progress_message
  end
end
