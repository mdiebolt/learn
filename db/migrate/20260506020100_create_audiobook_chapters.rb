class CreateAudiobookChapters < ActiveRecord::Migration[8.2]
  def change
    create_table :audiobook_chapters do |t|
      t.references :audiobook, null: false, foreign_key: true
      t.string :title
      t.integer :start_time_ms, null: false
      t.integer :end_time_ms, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :audiobook_chapters, [ :audiobook_id, :position ], unique: true
  end
end
