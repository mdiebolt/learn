class AddTranscriptionStatusToAudiobookChapters < ActiveRecord::Migration[8.2]
  def change
    add_column :audiobook_chapters, :transcription_status, :integer, default: 0, null: false
  end
end
