class AudiobooksController < ApplicationController
  before_action :set_audiobook, only: [ :show, :destroy ]

  def index
    @audiobooks = Current.user.audiobooks.with_attached_cover.recent
  end

  def show
    @progresses_by_chapter_id = @audiobook.progresses_by_chapter_id(Current.user)
    @study_guides_by_chapter_id = @audiobook.study_guides_by_chapter_id(Current.user)
  end

  def new
    @audiobook = Audiobook.new
  end

  def create
    @audiobook = Current.user.audiobooks.new(audiobook_params)

    if @audiobook.save
      redirect_to @audiobook
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @audiobook.destroy
    redirect_to audiobooks_path, notice: "Audiobook deleted."
  end

  private

  def set_audiobook
    @audiobook = Current.user.audiobooks.find(params[:id])
  end

  def audiobook_params
    params.expect(audiobook: [ :audio ])
  end
end
