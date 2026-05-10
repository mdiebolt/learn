class RequireAudiobookChapterTitle < ActiveRecord::Migration[8.2]
  def change
    change_column_null :audiobook_chapters, :title, false
  end
end
