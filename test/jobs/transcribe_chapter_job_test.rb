require "test_helper"

class TranscribeChapterJobTest < ActiveJob::TestCase
  setup do
    @chapter = chapters(:one)
  end

  test "a non-rate-limit error marks the chapter failed and re-raises" do
    def @chapter.transcribe_segment!(*) = raise "boom"

    assert_raises(RuntimeError) { TranscribeChapterJob.new.perform(@chapter) }

    assert @chapter.reload.transcription_failed?
  end

  test "a rate-limit error re-raises for retry without marking the chapter failed" do
    def @chapter.transcribe_segment!(*) = raise ElevenLabs::Scribe::RateLimitError, "429"

    assert_raises(ElevenLabs::Scribe::RateLimitError) { TranscribeChapterJob.new.perform(@chapter) }

    refute @chapter.reload.transcription_failed?
  end

  test "rate-limit errors retry with backoff under a global cap below the ElevenLabs limit" do
    assert_includes TranscribeChapterJob.rescue_handlers.map(&:first),
      "ElevenLabs::Scribe::RateLimitError"
    assert_operator TranscribeChapterJob.concurrency_limit, :<, 12
  end

  test "exhausting rate-limit retries marks the chapter failed" do
    def @chapter.transcribe_segment!(*) = raise ElevenLabs::Scribe::RateLimitError, "429"
    job = TranscribeChapterJob.new(@chapter)
    # Pretend this RateLimitError has already retried past the attempt budget,
    # so this run takes the exhaustion branch instead of re-enqueuing.
    job.exception_executions = { [ ElevenLabs::Scribe::RateLimitError ].to_s => 99 }

    job.perform_now

    assert @chapter.reload.transcription_failed?
  end
end
