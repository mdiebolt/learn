class FlattenAudiobookNamespaces < ActiveRecord::Migration[8.2]
  TABLE_RENAMES = {
    "audiobook_chapters"                      => "chapters",
    "audiobook_chapter_words"                 => "chapter_words",
    "audiobook_chapter_progresses"            => "chapter_progresses",
    "audiobook_chapter_cards"                 => "cards",
    "audiobook_chapter_card_reviews"          => "card_reviews",
    "audiobook_chapter_card_clozes"           => "card_clozes",
    "audiobook_chapter_card_free_responses"   => "card_free_responses",
    "audiobook_chapter_card_matchings"        => "card_matchings",
    "audiobook_chapter_card_multiple_choices" => "card_multiple_choices",
    "audiobook_chapter_card_orderings"        => "card_orderings",
    "audiobook_chapter_study_guides"          => "study_guides",
    "audiobook_chapter_study_guide_items"     => "study_guide_items",
    "audiobook_chapter_visuals"               => "visuals",
    "audiobook_chapter_visual_diagrams"       => "visual_diagrams",
    "audiobook_chapter_visual_timelines"      => "visual_timelines",
    "audiobook_chapter_visual_comparisons"    => "visual_comparisons"
  }.freeze

  # Performed against the *new* table names, after the table renames have run.
  COLUMN_RENAMES = [
    [ "cards",             "audiobook_chapter_id",              "chapter_id" ],
    [ "cards",             "audiobook_chapter_study_guide_id",  "study_guide_id" ],
    [ "card_reviews",      "audiobook_chapter_card_id",         "card_id" ],
    [ "study_guides",      "audiobook_chapter_id",              "chapter_id" ],
    [ "study_guide_items", "audiobook_chapter_study_guide_id",  "study_guide_id" ],
    [ "visuals",           "audiobook_chapter_study_guide_id",  "study_guide_id" ]
  ].freeze

  KIND_TYPE_RENAMES = {
    "Audiobook::Chapter::Card::MultipleChoice" => "Card::MultipleChoice",
    "Audiobook::Chapter::Card::Cloze"          => "Card::Cloze",
    "Audiobook::Chapter::Card::FreeResponse"   => "Card::FreeResponse",
    "Audiobook::Chapter::Card::Ordering"       => "Card::Ordering",
    "Audiobook::Chapter::Card::Matching"       => "Card::Matching",
    "Audiobook::Chapter::Visual::Diagram"      => "Visual::Diagram",
    "Audiobook::Chapter::Visual::Timeline"     => "Visual::Timeline",
    "Audiobook::Chapter::Visual::Comparison"   => "Visual::Comparison"
  }.freeze

  ITEMABLE_TYPE_RENAMES = {
    "Audiobook::Chapter::Card"   => "Card",
    "Audiobook::Chapter::Visual" => "Visual"
  }.freeze

  def up
    TABLE_RENAMES.each { |old, new| rename_table old, new }
    COLUMN_RENAMES.each { |table, old, new| rename_column table, old, new }

    # rename_table + rename_column auto-rename indexes that follow the standard
    # `index_<table>_on_<col>` convention. The renames below cover the indexes
    # whose names didn't follow that convention; look them up by column so we
    # don't depend on the partially-derived names Rails leaves behind.
    rename_index_for_columns "cards",             %w[study_guide_id],              "index_cards_on_study_guide_id"
    rename_index_for_columns "visuals",           %w[study_guide_id],              "index_visuals_on_study_guide_id"
    rename_index_for_columns "study_guide_items", %w[study_guide_id position],     "index_study_guide_items_on_study_guide_id_and_position"
    rename_index_for_columns "study_guide_items", %w[study_guide_id],              "index_study_guide_items_on_study_guide_id"

    update_polymorphic_type "cards",             "kind_type",     KIND_TYPE_RENAMES
    update_polymorphic_type "visuals",           "kind_type",     KIND_TYPE_RENAMES
    update_polymorphic_type "study_guide_items", "itemable_type", ITEMABLE_TYPE_RENAMES
  end

  def down
    update_polymorphic_type "study_guide_items", "itemable_type", ITEMABLE_TYPE_RENAMES.invert
    update_polymorphic_type "visuals",           "kind_type",     KIND_TYPE_RENAMES.invert
    update_polymorphic_type "cards",             "kind_type",     KIND_TYPE_RENAMES.invert

    rename_index_for_columns "study_guide_items", %w[study_guide_id],          "index_study_guide_items_on_guide_id"
    rename_index_for_columns "study_guide_items", %w[study_guide_id position], "index_study_guide_items_on_guide_id_and_position"
    rename_index_for_columns "visuals",           %w[study_guide_id],          "idx_on_audiobook_chapter_study_guide_id_749ef93672"
    rename_index_for_columns "cards",             %w[study_guide_id],          "idx_on_audiobook_chapter_study_guide_id_199e471d93"

    COLUMN_RENAMES.reverse_each { |table, old, new| rename_column table, new, old }
    TABLE_RENAMES.to_a.reverse_each { |old, new| rename_table new, old }
  end

  private

  def rename_index_for_columns(table, columns, new_name)
    index = connection.indexes(table).find { |i| i.columns == columns }
    raise "expected an index on #{table}(#{columns.join(', ')})" unless index
    return if index.name == new_name
    rename_index table, index.name, new_name
  end

  def update_polymorphic_type(table, column, mapping)
    mapping.each do |old, new|
      execute "UPDATE #{quote_table_name(table)} SET #{quote_column_name(column)} = #{quote(new)} WHERE #{quote_column_name(column)} = #{quote(old)}"
    end
  end
end
