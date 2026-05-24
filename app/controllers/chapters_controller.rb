class ChaptersController < ApplicationController
  include ChapterScoped

  def show
    @progress = Current.user.chapter_progresses.find_by(chapter: @chapter)
  end
end
