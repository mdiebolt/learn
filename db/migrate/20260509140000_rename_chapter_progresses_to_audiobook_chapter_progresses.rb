class RenameChapterProgressesToAudiobookChapterProgresses < ActiveRecord::Migration[8.2]
  def change
    rename_table :chapter_progresses, :audiobook_chapter_progresses
  end
end
