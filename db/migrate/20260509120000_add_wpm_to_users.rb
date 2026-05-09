class AddWpmToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :wpm, :integer, default: 250, null: false
  end
end
