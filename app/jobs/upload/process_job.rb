class Upload::ProcessJob < ApplicationJob
  queue_as :default

  def perform(upload_id)
    Upload.find(upload_id).process!
  end
end
