class RemoveAudioOffsetMsFromUsers < ActiveRecord::Migration[8.2]
  def change
    remove_column :users, :audio_offset_ms, :integer, default: 0, null: false
  end
end
