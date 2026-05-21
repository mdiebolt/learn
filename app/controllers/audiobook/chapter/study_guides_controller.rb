class Audiobook::Chapter::StudyGuidesController < ApplicationController
  before_action :set_chapter

  def show
    @study_guide = @chapter.study_guides.where(user: Current.user).order(created_at: :desc).first
    @items = @study_guide ? @study_guide.items.includes(:itemable) : []
  end

  def create
    Audiobook::Chapter::StudyGuide::GenerateJob.perform_later(@chapter, Current.user)
    redirect_to audiobook_chapter_study_guide_path(@audiobook, @chapter),
      notice: "Generating study guide…"
  end

  private

  def set_chapter
    @audiobook = Current.user.audiobooks.find(params[:audiobook_id])
    @chapter = @audiobook.chapters.find(params[:chapter_id])
  end
end
