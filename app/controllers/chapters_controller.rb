class ChaptersController < ApplicationController
  before_action :set_audiobook
  before_action :set_chapter

  def show
    transcript = @audiobook.transcript

    @words =
      if transcript&.ready?
        transcript.words
          .where("start_time_ms >= ? AND start_time_ms < ?",
                 @chapter.start_time_ms, @chapter.end_time_ms)
          .pluck(:text, :start_time_ms, :orp_index)
          .map { |text, start_ms, orp| { text: text, start: start_ms, orp: orp } }
      else
        []
      end
  end

  private

  def set_audiobook
    @audiobook = Current.user.audiobooks.find(params[:audiobook_id])
  end

  def set_chapter
    @chapter = @audiobook.chapters.find(params[:id])
  end
end
