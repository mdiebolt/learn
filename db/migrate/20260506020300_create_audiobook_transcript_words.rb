class CreateAudiobookTranscriptWords < ActiveRecord::Migration[8.2]
  def change
    create_table :audiobook_transcript_words do |t|
      t.references :transcript, null: false,
        foreign_key: { to_table: :audiobook_transcripts }
      t.string :text, null: false
      t.integer :start_time_ms, null: false
      t.integer :end_time_ms, null: false
      t.integer :position, null: false
      t.integer :orp_index, default: 0, null: false

      t.timestamps
    end

    add_index :audiobook_transcript_words, [ :transcript_id, :position ], unique: true
    add_index :audiobook_transcript_words, [ :transcript_id, :start_time_ms ],
      name: "index_audiobook_transcript_words_on_start_time"
  end
end
