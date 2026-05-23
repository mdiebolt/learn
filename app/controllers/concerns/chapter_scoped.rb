module ChapterScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_chapter
  end

  private
    def set_chapter
      @chapter = Current.user.chapters.find(params[:chapter_id] || params[:id])
    end
end
