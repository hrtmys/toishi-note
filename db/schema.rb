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

ActiveRecord::Schema[8.1].define(version: 2026_08_15_120000) do
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

  create_table "folders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "notebook_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["notebook_id"], name: "index_folders_on_notebook_id"
  end

  create_table "notebooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_notebooks_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "folder_id", null: false
    t.boolean "is_pinned", default: false, null: false
    t.datetime "last_viewed_at"
    t.integer "lock_version", default: 0, null: false
    t.string "note_type", null: false
    t.integer "notebook_id", null: false
    t.string "title"
    t.boolean "title_customized", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["folder_id"], name: "index_notes_on_folder_id"
    t.index ["last_viewed_at"], name: "index_notes_on_last_viewed_at"
    t.index ["notebook_id"], name: "index_notes_on_notebook_id"
  end

  create_table "scrap_items", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "note_id", null: false
    t.integer "position", null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["note_id"], name: "index_scrap_items_on_note_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "todo_items", force: :cascade do |t|
    t.string "content"
    t.datetime "created_at", null: false
    t.date "due_date"
    t.boolean "is_checked", default: false, null: false
    t.integer "note_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id"], name: "index_todo_items_on_note_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "compare_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.boolean "editor_fab_enabled", default: false, null: false
    t.string "email_address", null: false
    t.boolean "keep_original_images", default: false, null: false
    t.string "locale"
    t.string "password_digest", null: false
    t.datetime "registered_at", null: false
    t.integer "role", default: 0, null: false
    t.boolean "table_paste_enabled", default: false, null: false
    t.boolean "trusted_header_owner", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["trusted_header_owner"], name: "index_users_on_trusted_header_owner", unique: true, where: "trusted_header_owner"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "folders", "notebooks"
  add_foreign_key "notebooks", "users"
  add_foreign_key "notes", "folders"
  add_foreign_key "notes", "notebooks"
  add_foreign_key "scrap_items", "notes"
  add_foreign_key "sessions", "users"
  add_foreign_key "todo_items", "notes"
end
