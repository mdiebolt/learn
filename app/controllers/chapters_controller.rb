class ChaptersController < ApplicationController
  before_action :set_chapter

  def show
    @audiobook = @chapter.audiobook
    @words = @chapter.playback_words
    @next_chapter = @chapter.following
    @autoplay = params[:autoplay] == "1"
    @progress = Current.user.chapter_progresses.find_by(chapter_id: @chapter.id)
  end

  private

  def set_chapter
    @chapter = Current.user.chapters.find(params[:id])
  end
end
