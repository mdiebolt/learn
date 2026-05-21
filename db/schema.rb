# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_05_20_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audiobook_chapter_card_clozes", force: :cascade do |t|
    t.text "answers", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "text", null: false
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_card_free_responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "question", null: false
    t.text "reference_answer", null: false
    t.text "rubric"
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_card_matchings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "pairs", default: [], null: false
    t.text "prompt", null: false
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_card_multiple_choices", force: :cascade do |t|
    t.integer "correct_index", null: false
    t.datetime "created_at", null: false
    t.text "options", default: [], null: false, array: true
    t.text "question", null: false
    t.text "rationale"
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_card_orderings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "items", default: [], null: false, array: true
    t.text "prompt", null: false
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_card_reviews", force: :cascade do |t|
    t.bigint "audiobook_chapter_card_id", null: false
    t.datetime "created_at", null: false
    t.integer "last_elapsed_days", null: false
    t.integer "learning_steps", null: false
    t.float "prior_difficulty", null: false
    t.datetime "prior_due", null: false
    t.integer "prior_elapsed_days", null: false
    t.float "prior_stability", null: false
    t.integer "prior_state", null: false
    t.integer "rating", null: false
    t.jsonb "response"
    t.datetime "reviewed_at", null: false
    t.integer "scheduled_days", null: false
    t.datetime "updated_at", null: false
    t.index ["audiobook_chapter_card_id", "reviewed_at"], name: "index_card_reviews_on_card_id_and_reviewed_at"
  end

  create_table "audiobook_chapter_cards", force: :cascade do |t|
    t.bigint "audiobook_chapter_id", null: false
    t.bigint "audiobook_chapter_study_guide_id"
    t.string "concept_title", null: false
    t.datetime "created_at", null: false
    t.float "difficulty", default: 0.0, null: false
    t.datetime "due", null: false
    t.integer "elapsed_days", default: 0, null: false
    t.bigint "kind_id", null: false
    t.string "kind_type", null: false
    t.integer "lapses", default: 0, null: false
    t.datetime "last_review"
    t.integer "learning_steps", default: 0, null: false
    t.integer "reps", default: 0, null: false
    t.integer "scheduled_days", default: 0, null: false
    t.text "source_excerpt"
    t.float "stability", default: 0.0, null: false
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["audiobook_chapter_id"], name: "index_audiobook_chapter_cards_on_audiobook_chapter_id"
    t.index ["audiobook_chapter_study_guide_id"], name: "idx_on_audiobook_chapter_study_guide_id_199e471d93"
    t.index ["kind_type", "kind_id"], name: "index_audiobook_chapter_cards_on_kind_type_and_kind_id"
    t.index ["user_id", "due"], name: "index_audiobook_chapter_cards_on_user_id_and_due"
  end

  create_table "audiobook_chapter_progresses", force: :cascade do |t|
    t.bigint "chapter_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "progress_ms", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["chapter_id"], name: "index_audiobook_chapter_progresses_on_chapter_id"
    t.index ["user_id", "chapter_id"], name: "index_audiobook_chapter_progresses_on_user_id_and_chapter_id", unique: true
  end

  create_table "audiobook_chapter_study_guide_items", force: :cascade do |t|
    t.bigint "audiobook_chapter_study_guide_id", null: false
    t.datetime "created_at", null: false
    t.bigint "itemable_id", null: false
    t.string "itemable_type", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["audiobook_chapter_study_guide_id", "position"], name: "index_study_guide_items_on_guide_id_and_position", unique: true
    t.index ["audiobook_chapter_study_guide_id"], name: "index_study_guide_items_on_guide_id"
    t.index ["itemable_type", "itemable_id"], name: "index_study_guide_items_on_itemable"
  end

  create_table "audiobook_chapter_study_guides", force: :cascade do |t|
    t.bigint "audiobook_chapter_id", null: false
    t.datetime "created_at", null: false
    t.string "model"
    t.string "prompt_version"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["audiobook_chapter_id"], name: "index_audiobook_chapter_study_guides_on_audiobook_chapter_id"
    t.index ["user_id"], name: "index_audiobook_chapter_study_guides_on_user_id"
  end

  create_table "audiobook_chapter_visual_comparisons", force: :cascade do |t|
    t.text "columns", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.jsonb "rows", default: [], null: false
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_visual_diagrams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "edges", default: [], null: false
    t.jsonb "nodes", default: [], null: false
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_visual_timelines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "events", default: [], null: false
    t.datetime "updated_at", null: false
  end

  create_table "audiobook_chapter_visuals", force: :cascade do |t|
    t.bigint "audiobook_chapter_study_guide_id", null: false
    t.string "caption"
    t.datetime "created_at", null: false
    t.bigint "kind_id", null: false
    t.string "kind_type", null: false
    t.datetime "updated_at", null: false
    t.index ["audiobook_chapter_study_guide_id"], name: "idx_on_audiobook_chapter_study_guide_id_749ef93672"
    t.index ["kind_type", "kind_id"], name: "index_audiobook_chapter_visuals_on_kind_type_and_kind_id"
  end

  create_table "audiobook_chapter_words", force: :cascade do |t|
    t.bigint "chapter_id", null: false
    t.datetime "created_at", null: false
    t.integer "end_time_ms", null: false
    t.integer "orp_index", default: 0, null: false
    t.integer "position", null: false
    t.integer "start_time_ms", null: false
    t.string "text", null: false
    t.datetime "updated_at", null: false
    t.index ["chapter_id", "position"], name: "index_audiobook_chapter_words_on_chapter_id_and_position", unique: true
    t.index ["chapter_id", "start_time_ms"], name: "index_audiobook_chapter_words_on_chapter_id_and_start_time_ms"
    t.index ["chapter_id"], name: "index_audiobook_chapter_words_on_chapter_id"
  end

  create_table "audiobook_chapters", force: :cascade do |t|
    t.bigint "audiobook_id", null: false
    t.datetime "created_at", null: false
    t.integer "end_time_ms", null: false
    t.integer "position", null: false
    t.integer "start_time_ms", null: false
    t.string "title", null: false
    t.integer "transcription_status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["audiobook_id", "position"], name: "index_audiobook_chapters_on_audiobook_id_and_position", unique: true
    t.index ["audiobook_id"], name: "index_audiobook_chapters_on_audiobook_id"
  end

  create_table "audiobooks", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_audiobooks_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "audio_offset_ms", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "wpm", default: 250, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audiobook_chapter_card_reviews", "audiobook_chapter_cards"
  add_foreign_key "audiobook_chapter_cards", "audiobook_chapter_study_guides"
  add_foreign_key "audiobook_chapter_cards", "audiobook_chapters"
  add_foreign_key "audiobook_chapter_cards", "users"
  add_foreign_key "audiobook_chapter_progresses", "audiobook_chapters", column: "chapter_id"
  add_foreign_key "audiobook_chapter_progresses", "users"
  add_foreign_key "audiobook_chapter_study_guide_items", "audiobook_chapter_study_guides"
  add_foreign_key "audiobook_chapter_study_guides", "audiobook_chapters"
  add_foreign_key "audiobook_chapter_study_guides", "users"
  add_foreign_key "audiobook_chapter_visuals", "audiobook_chapter_study_guides"
  add_foreign_key "audiobook_chapter_words", "audiobook_chapters", column: "chapter_id"
  add_foreign_key "audiobook_chapters", "audiobooks"
  add_foreign_key "audiobooks", "users"
  add_foreign_key "sessions", "users"
end
