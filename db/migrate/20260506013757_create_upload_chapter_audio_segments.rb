class CreateUploadChapterAudioSegments < ActiveRecord::Migration[8.2]
  def change
    create_table :upload_chapter_audio_segments do |t|
      t.references :chapter, null: false, foreign_key: { to_table: :upload_chapters }
      t.jsonb :timestamps
      t.integer :status, default: 0, null: false
      t.float :duration_seconds

      t.timestamps
    end
  end
end
