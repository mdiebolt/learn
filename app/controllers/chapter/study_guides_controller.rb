class Chapter::StudyGuidesController < ApplicationController
  include ChapterScoped, RenderPartialsWithoutNamespace

  def show
    @audiobook = @chapter.audiobook
    @study_guide = @chapter.study_guides.where(user: Current.user).order(created_at: :desc).first
    @topics = @study_guide ? @study_guide.topics.includes(:topical) : []
  end

  def create
    GenerateStudyGuideJob.perform_later(@chapter, Current.user)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to chapter_study_guide_path(@chapter), notice: "Generating study guide…" }
    end
  end
end
