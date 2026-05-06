class Upload::Chapter::GenerateAudioJob < ApplicationJob
  queue_as :audio_generation

  retry_on ElevenLabs::Client::RateLimitError, wait: :polynomially_longer, attempts: 5

  def perform(chapter_id)
    chapter = Upload::Chapter.find(chapter_id)
    segment = chapter.audio_segment || chapter.create_audio_segment!(status: :pending)
    segment.generate!
  end
end
