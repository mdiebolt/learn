class UploadsController < ApplicationController
  before_action :require_authentication
  before_action :set_upload, only: [:show, :destroy]

  def index
    @uploads = Current.user.uploads.order(created_at: :desc)
  end

  def show
  end

  def new
    @upload = Upload.new
  end

  def create
    @upload = Current.user.uploads.new(upload_params)

    if @upload.save
      Upload::ProcessJob.perform_later(@upload.id)
      redirect_to @upload, notice: "Upload is being processed..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @upload.destroy
    redirect_to uploads_path, notice: "Upload deleted."
  end

  private

  def set_upload
    @upload = Current.user.uploads.find(params[:id])
  end

  def upload_params
    params.require(:upload).permit(:source_file)
  end
end
