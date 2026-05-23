require "test_helper"

class AudiobookTest < ActiveSupport::TestCase
  test "rejects unsupported audio formats" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(fixture_file_upload("silent.wav", "audio/wav"))

    assert_not audiobook.valid?
    assert_includes audiobook.errors[:audio], "must be an M4B or MP3 file"
  end

  test "accepts m4b" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(fixture_file_upload("silent.m4b", "audio/mp4"))

    assert audiobook.valid?
  end

  test "accepts mp3" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(fixture_file_upload("silent.mp3", "audio/mpeg"))

    assert audiobook.valid?
  end

  test "title falls back to the filename without its extension when blank" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(fixture_file_upload("silent.m4b", "audio/mp4"))
    audiobook.valid?

    assert_equal "silent", audiobook.title
  end
end
