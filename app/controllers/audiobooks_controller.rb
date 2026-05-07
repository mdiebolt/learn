class AudiobooksController < ApplicationController
  before_action :set_audiobook, only: [:show, :destroy]

  def index
    @audiobooks = Current.user.audiobooks.recent
  end

  def show
  end

  def new
    @audiobook = Audiobook.new
  end

  def create
    @audiobook = Current.user.audiobooks.new(audiobook_params)

    if @audiobook.save
      redirect_to @audiobook, notice: "Audiobook uploaded."
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
    params.require(:audiobook).permit(:audio)
  end
end
