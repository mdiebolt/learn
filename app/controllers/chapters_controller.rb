class ChaptersController < ApplicationController
  include ChapterScoped

  def show
    @audiobook = @chapter.audiobook
    @words = @chapter.playback_words
    @next_chapter = @chapter.following
    @autoplay = params[:autoplay] == "1"
    @progress = Current.user.chapter_progresses.find_by(chapter_id: @chapter.id)
  end
end
