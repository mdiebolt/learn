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
end
