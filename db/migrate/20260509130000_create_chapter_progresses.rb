class CreateChapterProgresses < ActiveRecord::Migration[8.2]
  def change
    create_table :chapter_progresses do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :chapter, null: false, foreign_key: { to_table: :audiobook_chapters }
      t.integer :progress_ms, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end
    add_index :chapter_progresses, [ :user_id, :chapter_id ], unique: true
  end
end
