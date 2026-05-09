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

ActiveRecord::Schema[8.2].define(version: 2026_05_09_140000) do
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

  create_table "audiobook_chapters", force: :cascade do |t|
    t.bigint "audiobook_id", null: false
    t.datetime "created_at", null: false
    t.integer "end_time_ms", null: false
    t.integer "position", null: false
    t.integer "start_time_ms", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["audiobook_id", "position"], name: "index_audiobook_chapters_on_audiobook_id_and_position", unique: true
    t.index ["audiobook_id"], name: "index_audiobook_chapters_on_audiobook_id"
  end

  create_table "audiobook_transcript_words", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "end_time_ms", null: false
    t.integer "orp_index", default: 0, null: false
    t.integer "position", null: false
    t.integer "start_time_ms", null: false
    t.string "text", null: false
    t.bigint "transcript_id", null: false
    t.datetime "updated_at", null: false
    t.index ["transcript_id", "position"], name: "index_audiobook_transcript_words_on_transcript_id_and_position", unique: true
    t.index ["transcript_id", "start_time_ms"], name: "index_audiobook_transcript_words_on_start_time"
    t.index ["transcript_id"], name: "index_audiobook_transcript_words_on_transcript_id"
  end

  create_table "audiobook_transcripts", force: :cascade do |t|
    t.bigint "audiobook_id", null: false
    t.datetime "created_at", null: false
    t.string "progress_message"
    t.jsonb "raw_response"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["audiobook_id"], name: "index_audiobook_transcripts_on_audiobook_id", unique: true
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
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "wpm", default: 250, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audiobook_chapter_progresses", "audiobook_chapters", column: "chapter_id"
  add_foreign_key "audiobook_chapter_progresses", "users"
  add_foreign_key "audiobook_chapters", "audiobooks"
  add_foreign_key "audiobook_transcript_words", "audiobook_transcripts", column: "transcript_id"
  add_foreign_key "audiobook_transcripts", "audiobooks"
  add_foreign_key "audiobooks", "users"
  add_foreign_key "sessions", "users"
end
