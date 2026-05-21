class MoveTranscriptWordsToChapters < ActiveRecord::Migration[8.2]
  def up
    add_reference :audiobook_transcript_words, :chapter,
      foreign_key: { to_table: :audiobook_chapters }

    execute <<~SQL
      UPDATE audiobook_transcript_words AS w
      SET chapter_id = c.id
      FROM audiobook_transcripts AS t
      JOIN audiobook_chapters AS c ON c.audiobook_id = t.audiobook_id
      WHERE w.transcript_id = t.id
        AND w.start_time_ms >= c.start_time_ms
        AND w.start_time_ms < c.end_time_ms;
    SQL

    # Orphan rows (no matching chapter window) can't be migrated. They would
    # only exist if a transcribed audiobook lost its chapter detection — drop
    # them so the NOT NULL constraint can apply.
    execute "DELETE FROM audiobook_transcript_words WHERE chapter_id IS NULL;"

    change_column_null :audiobook_transcript_words, :chapter_id, false
    remove_index :audiobook_transcript_words, name: :index_audiobook_transcript_words_on_transcript_id
    remove_index :audiobook_transcript_words, name: :index_audiobook_transcript_words_on_transcript_id_and_position
    remove_index :audiobook_transcript_words, name: :index_audiobook_transcript_words_on_start_time
    remove_foreign_key :audiobook_transcript_words, :audiobook_transcripts
    remove_column :audiobook_transcript_words, :transcript_id

    rename_table :audiobook_transcript_words, :audiobook_chapter_words

    add_index :audiobook_chapter_words, [ :chapter_id, :position ], unique: true
    add_index :audiobook_chapter_words, [ :chapter_id, :start_time_ms ]

    drop_table :audiobook_transcripts
  end

  def down
    create_table :audiobook_transcripts do |t|
      t.references :audiobook, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, default: 0, null: false
      t.string :progress_message
      t.jsonb :raw_response
      t.timestamps
    end

    rename_table :audiobook_chapter_words, :audiobook_transcript_words

    add_reference :audiobook_transcript_words, :transcript,
      foreign_key: { to_table: :audiobook_transcripts }

    execute <<~SQL
      INSERT INTO audiobook_transcripts (audiobook_id, status, created_at, updated_at)
      SELECT DISTINCT c.audiobook_id, 2, NOW(), NOW()
      FROM audiobook_chapters AS c
      JOIN audiobook_transcript_words AS w ON w.chapter_id = c.id;
    SQL

    execute <<~SQL
      UPDATE audiobook_transcript_words AS w
      SET transcript_id = t.id
      FROM audiobook_chapters AS c
      JOIN audiobook_transcripts AS t ON t.audiobook_id = c.audiobook_id
      WHERE w.chapter_id = c.id;
    SQL

    change_column_null :audiobook_transcript_words, :transcript_id, false
    remove_index :audiobook_transcript_words, [ :chapter_id, :position ]
    remove_index :audiobook_transcript_words, [ :chapter_id, :start_time_ms ]
    remove_foreign_key :audiobook_transcript_words, :audiobook_chapters
    remove_column :audiobook_transcript_words, :chapter_id

    add_index :audiobook_transcript_words, [ :transcript_id, :position ], unique: true
    add_index :audiobook_transcript_words, [ :transcript_id, :start_time_ms ],
      name: :index_audiobook_transcript_words_on_start_time
  end
end
