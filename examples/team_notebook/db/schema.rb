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

ActiveRecord::Schema[8.1].define(version: 2026_10_20_000000) do
  create_table "articles", force: :cascade do |t|
    t.integer "team_id", null: false
    t.integer "author_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.boolean "published", default: false, null: false
    t.index ["author_id"], name: "index_articles_on_author_id"
    t.index ["team_id", "slug"], name: "index_articles_on_team_id_and_slug", unique: true
    t.index ["team_id"], name: "index_articles_on_team_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "team_id", null: false
    t.string "role", null: false
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id", "team_id"], name: "index_memberships_on_user_id_and_team_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.index ["slug"], name: "index_teams_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "articles", "teams"
  add_foreign_key "articles", "users", column: "author_id"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
end
