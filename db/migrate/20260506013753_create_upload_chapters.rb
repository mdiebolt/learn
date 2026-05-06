class CreateUploadChapters < ActiveRecord::Migration[8.2]
  def change
    create_table :upload_chapters do |t|
      t.references :upload, null: false, foreign_key: true
      t.string :title
      t.integer :position
      t.text :content
      t.jsonb :words, default: []

      t.timestamps
    end
    add_index :upload_chapters, [:upload_id, :position]
  end
end
