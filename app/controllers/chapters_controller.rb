class ChaptersController < ApplicationController
  before_action :set_audiobook
  before_action :set_chapter

  def show
    @words = @chapter.words_for_playback
    @next_chapter = @chapter.next_chapter
    @autoplay = params[:autoplay] == "1"
    @progress = Current.user.chapter_progresses.find_by(chapter_id: @chapter.id)
  end

  private

  def set_audiobook
    @audiobook = Current.user.audiobooks.find(params[:audiobook_id])
  end

  def set_chapter
    @chapter = @audiobook.chapters.find(params[:id])
  end
end
