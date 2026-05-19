require "test_helper"

class Audio::SegmentTest < ActiveSupport::TestCase
  test "a failed ffmpeg slice raises with the source range and ffmpeg's own error output" do
    error = assert_raises(RuntimeError) do
      Audio::Segment.extract("/no/such/audio.m4b", 0, 1_000) { flunk "should not yield" }
    end

    assert_match "ffmpeg failed to slice 0–1000ms from /no/such/audio.m4b", error.message
    assert_match(/No such file or directory|Error opening input/i, error.message)
  end
end
