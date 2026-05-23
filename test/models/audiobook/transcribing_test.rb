require "test_helper"

class Audiobook::TranscribingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @audiobook = audiobooks(:one)
  end

  test "transcription_status is :pending when every chapter is pending" do
    @audiobook.chapters.each(&:transcription_pending!)
    assert_equal :pending, @audiobook.reload.transcription_status
  end

  test "transcription_status is :transcribing while any chapter is in flight" do
    audiobook_chapters(:one).transcription_transcribing!
    audiobook_chapters(:two).transcription_pending!
    assert_equal :transcribing, @audiobook.reload.transcription_status
  end

  test "transcription_status is :ready once every chapter is ready" do
    @audiobook.chapters.each(&:transcription_ready!)
    assert_equal :ready, @audiobook.reload.transcription_status
  end

  test "transcription_status is :failed when any chapter failed and nothing is in flight" do
    audiobook_chapters(:one).transcription_ready!
    audiobook_chapters(:two).transcription_failed!
    assert_equal :failed, @audiobook.reload.transcription_status
  end

  test "transcription_progress_message counts ready chapters" do
    audiobook_chapters(:one).transcription_ready!
    audiobook_chapters(:two).transcription_transcribing!
    assert_equal "Transcribed 1 of 2 chapters…", @audiobook.reload.transcription_progress_message
  end

  test "transcribe! enqueues a chapter job per chapter and marks them transcribing" do
    assert_enqueued_jobs(@audiobook.chapters.size, only: Audiobook::Chapter::ScribeJob) do
      @audiobook.audio.attach(fixture_file_upload("silent.m4b", "audio/mp4"))
      @audiobook.transcribe!(force: true)
    end

    assert @audiobook.chapters.reload.all?(&:transcription_transcribing?)
  end

  test "transcribe! is a no-op when already ready and not forced" do
    @audiobook.chapters.each(&:transcription_ready!)

    assert_no_enqueued_jobs do
      @audiobook.transcribe!
    end
  end
end
