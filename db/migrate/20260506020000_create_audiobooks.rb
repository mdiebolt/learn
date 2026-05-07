class CreateAudiobooks < ActiveRecord::Migration[8.2]
  def change
    create_table :audiobooks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :author
      t.integer :status, default: 0, null: false
      t.integer :duration_ms

      t.timestamps
    end
  end
end
