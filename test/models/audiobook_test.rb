require "test_helper"

class AudiobookTest < ActiveSupport::TestCase
  test "rejects unsupported audio formats" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(
      io: StringIO.new("fake"),
      filename: "book.wav",
      content_type: "audio/wav"
    )

    assert_not audiobook.valid?
    assert_includes audiobook.errors[:audio], "must be an M4B or MP3 file"
  end

  test "accepts m4b" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(
      io: StringIO.new("fake"),
      filename: "book.m4b",
      content_type: "audio/mp4"
    )

    assert audiobook.valid?
  end

  test "accepts mp3" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(
      io: StringIO.new("fake"),
      filename: "book.mp3",
      content_type: "audio/mpeg"
    )

    assert audiobook.valid?
  end

  test "title defaults to the audio filename when blank" do
    audiobook = Audiobook.new(user: users(:one))
    audiobook.audio.attach(
      io: StringIO.new("fake"),
      filename: "filename.m4b",
      content_type: "audio/mp4"
    )
    audiobook.valid?

    assert_equal "filename.m4b", audiobook.title
  end
end
