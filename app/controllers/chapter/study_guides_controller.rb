class Chapter::StudyGuidesController < ApplicationController
  before_action :set_chapter

  def show
    @audiobook = @chapter.audiobook
    @study_guide = @chapter.study_guides.where(user: Current.user).order(created_at: :desc).first
    @items = @study_guide ? @study_guide.items.includes(:itemable) : []
  end

  def create
    StudyGuide::GenerateJob.perform_later(@chapter, Current.user)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to chapter_study_guide_path(@chapter), notice: "Generating study guide…" }
    end
  end

  private

  def set_chapter
    @chapter = Current.user.chapters.find(params[:chapter_id])
  end
end
