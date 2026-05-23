class Chapter::ProgressesController < ApplicationController
  include ChapterScoped

  def update
    progress = Current.user.chapter_progresses.find_or_initialize_by(chapter: @chapter)

    if progress.record(progress_params)
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  private
    def progress_params
      params.permit(:progress_ms, :completed)
    end
end
