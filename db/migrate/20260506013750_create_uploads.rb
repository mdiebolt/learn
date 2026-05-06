class CreateUploads < ActiveRecord::Migration[8.2]
  def change
    create_table :uploads do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :author
      t.integer :status, default: 0, null: false
      t.datetime :processed_at

      t.timestamps
    end
  end
end
