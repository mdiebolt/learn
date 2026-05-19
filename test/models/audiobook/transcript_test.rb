require "test_helper"

class Audiobook::TranscriptTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "default status is pending" do
    assert audiobook_transcripts(:one).pending?
  end

  test "dispatch_chapter_scribes! is a no-op when words exist and force is false" do
    transcript = audiobook_transcripts(:one)
    # The fixture has 2 words attached.
    refute transcript.words.empty?

    assert_no_enqueued_jobs do
      transcript.dispatch_chapter_scribes!(force: false)
    end
    refute transcript.words.reload.empty?
  end

  test "settle_chapter! advances the progress message while chapters are in flight" do
    transcript = audiobook_transcripts(:one)
    transcript.transcribing!
    audiobook_chapters(:one).transcription_ready!
    # Chapter :two is still pending.

    transcript.settle_chapter!

    assert transcript.reload.transcribing?
    assert_equal "Transcribed 1 of 2 chapters…", transcript.progress_message
  end

  test "settle_chapter! marks the transcript ready once every chapter is ready" do
    transcript = audiobook_transcripts(:one)
    transcript.transcribing!
    audiobook_chapters(:one).transcription_ready!
    audiobook_chapters(:two).transcription_ready!

    transcript.settle_chapter!

    assert transcript.reload.ready?
    assert_nil transcript.progress_message
  end

  test "settle_chapter! marks the transcript failed when any chapter failed" do
    transcript = audiobook_transcripts(:one)
    transcript.transcribing!
    audiobook_chapters(:one).transcription_ready!
    audiobook_chapters(:two).transcription_failed!

    transcript.settle_chapter!

    assert transcript.reload.failed?
  end
end
