class RenameStudyGuideItemsToTopics < ActiveRecord::Migration[8.2]
  def change
    rename_table :study_guide_items, :study_guide_topics
    rename_column :study_guide_topics, :itemable_id,   :topical_id
    rename_column :study_guide_topics, :itemable_type, :topical_type

    rename_index_for_columns :study_guide_topics,
      %w[topical_type topical_id],
      "index_study_guide_topics_on_topical"
    rename_index_for_columns :study_guide_topics,
      %w[study_guide_id position],
      "index_study_guide_topics_on_study_guide_id_and_position"
    rename_index_for_columns :study_guide_topics,
      %w[study_guide_id],
      "index_study_guide_topics_on_study_guide_id"
  end

  private

  def rename_index_for_columns(table, columns, new_name)
    index = connection.indexes(table).find { |i| i.columns == columns }
    raise "expected an index on #{table}(#{columns.join(', ')})" unless index
    return if index.name == new_name
    rename_index table, index.name, new_name
  end
end
