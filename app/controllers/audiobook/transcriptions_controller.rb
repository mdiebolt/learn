class Audiobook::TranscriptionsController < ApplicationController
  before_action :set_audiobook

  def create
    @audiobook.transcribe!
    redirect_to @audiobook, notice: "Transcription started. This may take a few minutes."
  end

  private

  def set_audiobook
    @audiobook = Current.user.audiobooks.find(params[:audiobook_id])
  end
end
