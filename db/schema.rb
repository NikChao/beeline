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

ActiveRecord::Schema[8.1].define(version: 2026_10_11_051453) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "drafts", force: :cascade do |t|
    t.integer "paper_id", null: false
    t.integer "number", null: false
    t.string "title", null: false
    t.string "author"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "client_key"
    t.index ["client_key"], name: "index_drafts_on_client_key", unique: true
    t.index ["paper_id", "number"], name: "index_drafts_on_paper_id_and_number", unique: true
    t.index ["paper_id"], name: "index_drafts_on_paper_id"
  end

  create_table "marks", force: :cascade do |t|
    t.integer "draft_id", null: false
    t.string "kind", null: false
    t.string "color", null: false
    t.json "points", null: false
    t.string "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "client_key"
    t.index ["client_key"], name: "index_marks_on_client_key", unique: true
    t.index ["draft_id"], name: "index_marks_on_draft_id"
  end

  create_table "papers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "publications", force: :cascade do |t|
    t.integer "paper_id", null: false
    t.integer "draft_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["draft_id"], name: "index_publications_on_draft_id"
    t.index ["paper_id"], name: "index_publications_on_paper_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "drafts", "papers"
  add_foreign_key "marks", "drafts"
  add_foreign_key "publications", "drafts"
  add_foreign_key "publications", "papers"
end
