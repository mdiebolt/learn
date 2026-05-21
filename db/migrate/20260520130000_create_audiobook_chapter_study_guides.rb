class CreateAudiobookChapterStudyGuides < ActiveRecord::Migration[8.2]
  def change
    create_table :audiobook_chapter_study_guides do |t|
      t.references :user, null: false, foreign_key: true
      t.references :audiobook_chapter, null: false,
        foreign_key: { to_table: :audiobook_chapters }
      t.string :model
      t.string :prompt_version
      t.timestamps
    end

    create_card_kind_tables
    create_cards_table
    create_visual_kind_tables
    create_visuals_table
    create_study_guide_items_table
    create_card_reviews_table
  end

  private

  def create_card_kind_tables
    create_table :audiobook_chapter_card_multiple_choices do |t|
      t.text :question, null: false
      t.text :options, array: true, null: false, default: []
      t.integer :correct_index, null: false
      t.text :rationale
      t.timestamps
    end

    create_table :audiobook_chapter_card_clozes do |t|
      t.text :text, null: false
      t.text :answers, array: true, null: false, default: []
      t.timestamps
    end

    create_table :audiobook_chapter_card_free_responses do |t|
      t.text :question, null: false
      t.text :reference_answer, null: false
      t.text :rubric
      t.timestamps
    end

    create_table :audiobook_chapter_card_orderings do |t|
      t.text :prompt, null: false
      t.text :items, array: true, null: false, default: []
      t.timestamps
    end

    create_table :audiobook_chapter_card_matchings do |t|
      t.text :prompt, null: false
      t.jsonb :pairs, null: false, default: []
      t.timestamps
    end
  end

  def create_cards_table
    create_table :audiobook_chapter_cards do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :audiobook_chapter, null: false,
        foreign_key: { to_table: :audiobook_chapters }
      t.references :audiobook_chapter_study_guide,
        foreign_key: { to_table: :audiobook_chapter_study_guides }
      t.string :concept_title, null: false
      t.text :source_excerpt
      t.string :kind_type, null: false
      t.bigint :kind_id, null: false
      t.datetime :due, null: false
      t.float :stability, null: false, default: 0.0
      t.float :difficulty, null: false, default: 0.0
      t.integer :elapsed_days, null: false, default: 0
      t.integer :scheduled_days, null: false, default: 0
      t.integer :learning_steps, null: false, default: 0
      t.integer :reps, null: false, default: 0
      t.integer :lapses, null: false, default: 0
      t.integer :state, null: false, default: 0
      t.datetime :last_review
      t.timestamps
    end

    add_index :audiobook_chapter_cards, [ :user_id, :due ]
    add_index :audiobook_chapter_cards, [ :kind_type, :kind_id ]
  end

  def create_visual_kind_tables
    create_table :audiobook_chapter_visual_diagrams do |t|
      t.jsonb :nodes, null: false, default: []
      t.jsonb :edges, null: false, default: []
      t.timestamps
    end

    create_table :audiobook_chapter_visual_timelines do |t|
      t.jsonb :events, null: false, default: []
      t.timestamps
    end

    create_table :audiobook_chapter_visual_comparisons do |t|
      t.text :columns, array: true, null: false, default: []
      t.jsonb :rows, null: false, default: []
      t.timestamps
    end
  end

  def create_visuals_table
    create_table :audiobook_chapter_visuals do |t|
      t.references :audiobook_chapter_study_guide, null: false,
        foreign_key: { to_table: :audiobook_chapter_study_guides }
      t.string :kind_type, null: false
      t.bigint :kind_id, null: false
      t.string :caption
      t.timestamps
    end

    add_index :audiobook_chapter_visuals, [ :kind_type, :kind_id ]
  end

  def create_study_guide_items_table
    create_table :audiobook_chapter_study_guide_items do |t|
      t.references :audiobook_chapter_study_guide, null: false,
        foreign_key: { to_table: :audiobook_chapter_study_guides },
        index: { name: :index_study_guide_items_on_guide_id }
      t.integer :position, null: false
      t.string :itemable_type, null: false
      t.bigint :itemable_id, null: false
      t.timestamps
    end

    add_index :audiobook_chapter_study_guide_items,
      [ :itemable_type, :itemable_id ],
      name: :index_study_guide_items_on_itemable
    add_index :audiobook_chapter_study_guide_items,
      [ :audiobook_chapter_study_guide_id, :position ],
      unique: true,
      name: :index_study_guide_items_on_guide_id_and_position
  end

  def create_card_reviews_table
    create_table :audiobook_chapter_card_reviews do |t|
      t.references :audiobook_chapter_card, null: false,
        foreign_key: { to_table: :audiobook_chapter_cards },
        index: false
      t.integer :rating, null: false
      t.jsonb :response
      t.datetime :reviewed_at, null: false
      t.integer :prior_state, null: false
      t.datetime :prior_due, null: false
      t.float :prior_stability, null: false
      t.float :prior_difficulty, null: false
      t.integer :prior_elapsed_days, null: false
      t.integer :last_elapsed_days, null: false
      t.integer :scheduled_days, null: false
      t.integer :learning_steps, null: false
      t.timestamps
    end

    add_index :audiobook_chapter_card_reviews,
      [ :audiobook_chapter_card_id, :reviewed_at ],
      name: :index_card_reviews_on_card_id_and_reviewed_at
  end
end
