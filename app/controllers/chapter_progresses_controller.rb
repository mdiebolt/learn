class ChapterProgressesController < ApplicationController
  before_action :set_chapter

  def update
    progress = Current.user.chapter_progresses.find_or_initialize_by(chapter: @chapter)
    progress.progress_ms = params[:progress_ms].to_i if params.key?(:progress_ms)
    progress.completed_at ||= Time.current if params[:completed].to_s == "true"

    if progress.save
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  private

  def set_chapter
    audiobook = Current.user.audiobooks.find(params[:audiobook_id])
    @chapter = audiobook.chapters.find(params[:chapter_id])
  end
end
