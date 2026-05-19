module Audiobook::Transcribable
  extend ActiveSupport::Concern

  included do
    has_one :transcript, class_name: "Audiobook::Transcript", dependent: :destroy
  end

  def transcribe!
    (transcript || create_transcript!).update!(status: :pending, progress_message: nil)
    Audiobook::ScribeJob.perform_later(id)
  end
end
