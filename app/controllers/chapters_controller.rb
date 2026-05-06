class ChaptersController < ApplicationController
  before_action :require_authentication
  before_action :set_upload
  before_action :set_chapter

  def show
    ensure_audio_generation
  end

  def audio_status
    segment = @chapter.audio_segment

    respond_to do |format|
      format.json do
        render json: {
          status: segment&.status || "pending",
          audio_url: segment&.ready? ? url_for(segment.audio_file) : nil,
          timestamps: segment&.ready? ? segment.timestamps : nil,
          duration: segment&.formatted_duration
        }
      end

      format.turbo_stream do
        if segment&.ready?
          render turbo_stream: turbo_stream.replace(
            "audio-player",
            partial: "uploads/chapters/audio_player",
            locals: { chapter: @chapter, segment: segment }
          )
        else
          head :no_content
        end
      end
    end
  end

  private

  def set_upload
    @upload = Current.user.uploads.find(params[:upload_id])
  end

  def set_chapter
    @chapter = @upload.chapters.find(params[:id])
  end

  def ensure_audio_generation
    segment = @chapter.audio_segment

    if segment.nil?
      @chapter.create_audio_segment!(status: :pending)
      Upload::Chapter::GenerateAudioJob.perform_later(@chapter.id)
    elsif segment.failed?
      segment.pending!
      Upload::Chapter::GenerateAudioJob.perform_later(@chapter.id)
    end
  end
end
