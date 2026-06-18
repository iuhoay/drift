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

ActiveRecord::Schema[8.2].define(version: 2026_06_17_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "entries", force: :cascade do |t|
    t.string "author"
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "feed_id", null: false
    t.string "guid", null: false
    t.datetime "published_at"
    t.tsvector "search_vector"
    t.text "summary"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["feed_id", "guid"], name: "index_entries_on_feed_id_and_guid", unique: true
    t.index ["feed_id"], name: "index_entries_on_feed_id"
    t.index ["published_at"], name: "index_entries_on_published_at"
    t.index ["search_vector"], name: "index_entries_on_search_vector", using: :gin
  end

  create_table "feeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "dead_at"
    t.text "description"
    t.string "etag"
    t.string "feed_url", null: false
    t.integer "fetch_failure_count", default: 0, null: false
    t.string "kind", default: "rss", null: false
    t.text "last_error"
    t.datetime "last_fetched_at"
    t.string "last_modified"
    t.datetime "last_success_at"
    t.datetime "next_fetch_at"
    t.string "site_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["feed_url"], name: "index_feeds_on_feed_url", unique: true
    t.index ["next_fetch_at"], name: "index_feeds_on_next_fetch_at"
  end

  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "saved_items", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.text "excerpt"
    t.string "image_url"
    t.datetime "read_at"
    t.datetime "saved_at", null: false
    t.tsvector "search_vector"
    t.string "site_name"
    t.datetime "starred_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.bigint "user_id", null: false
    t.index ["search_vector"], name: "index_saved_items_on_search_vector", using: :gin
    t.index ["user_id", "read_at"], name: "index_saved_items_on_user_id_and_read_at"
    t.index ["user_id", "saved_at"], name: "index_saved_items_on_user_id_and_saved_at"
    t.index ["user_id", "starred_at"], name: "index_saved_items_on_user_id_and_starred_at"
    t.index ["user_id", "url"], name: "index_saved_items_on_user_id_and_url", unique: true
    t.index ["user_id"], name: "index_saved_items_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "custom_title"
    t.bigint "feed_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["feed_id"], name: "index_subscriptions_on_feed_id"
    t.index ["user_id", "feed_id"], name: "index_subscriptions_on_user_id_and_feed_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "user_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entry_id", null: false
    t.datetime "read_at"
    t.datetime "starred_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["entry_id"], name: "index_user_entries_on_entry_id"
    t.index ["user_id", "entry_id"], name: "index_user_entries_on_user_id_and_entry_id", unique: true
    t.index ["user_id", "read_at"], name: "index_user_entries_on_user_id_and_read_at"
    t.index ["user_id", "starred_at"], name: "index_user_entries_on_user_id_and_starred_at"
    t.index ["user_id"], name: "index_user_entries_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "entries", "feeds"
  add_foreign_key "identities", "users"
  add_foreign_key "saved_items", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "feeds"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "user_entries", "entries"
  add_foreign_key "user_entries", "users"
end
