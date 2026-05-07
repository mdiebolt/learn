class AddProgressMessageToAudiobookTranscripts < ActiveRecord::Migration[8.2]
  def change
    add_column :audiobook_transcripts, :progress_message, :string
  end
end
