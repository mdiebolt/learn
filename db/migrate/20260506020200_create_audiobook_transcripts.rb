class CreateAudiobookTranscripts < ActiveRecord::Migration[8.2]
  def change
    create_table :audiobook_transcripts do |t|
      t.references :audiobook, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, default: 0, null: false
      t.jsonb :raw_response

      t.timestamps
    end
  end
end
