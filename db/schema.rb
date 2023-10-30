# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 22) do

  create_table "informs", force: :cascade do |t|
    t.string   "form",       limit: 255
    t.string   "data",       limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "user_agent",             default: "unknown"
  end

  add_index "informs", ["form"], name: "index_informs_on_form"

  create_table "jabbers", force: :cascade do |t|
    t.integer "user_id"
    t.text    "jid"
    t.text    "nick"
  end

  add_index "jabbers", ["jid"], name: "index_jabbers_on_jid", unique: true
  add_index "jabbers", ["user_id"], name: "index_jabbers_on_user_id", unique: true

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer  "resource_owner_id", null: false
    t.integer  "application_id",    null: false
    t.string   "token",             null: false
    t.integer  "expires_in",        null: false
    t.text     "redirect_uri",      null: false
    t.datetime "created_at",        null: false
    t.datetime "revoked_at"
    t.string   "scopes"
  end

  add_index "oauth_access_grants", ["token"], name: "index_oauth_access_grants_on_token", unique: true

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer  "resource_owner_id"
    t.integer  "application_id"
    t.string   "token",                               null: false
    t.string   "refresh_token"
    t.integer  "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at",                          null: false
    t.string   "scopes"
    t.string   "previous_refresh_token", default: "", null: false
  end

  add_index "oauth_access_tokens", ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
  add_index "oauth_access_tokens", ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
  add_index "oauth_access_tokens", ["token"], name: "index_oauth_access_tokens_on_token", unique: true

  create_table "oauth_applications", force: :cascade do |t|
    t.string   "name",                        null: false
    t.string   "uid",                         null: false
    t.string   "secret",                      null: false
    t.text     "redirect_uri",                null: false
    t.string   "scopes",       default: "",   null: false
    t.boolean  "confidential", default: true, null: false
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "oauth_applications", ["uid"], name: "index_oauth_applications_on_uid", unique: true

  create_table "sessions", force: :cascade do |t|
    t.string   "session_id", limit: 255, null: false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", unique: true
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at"

  create_table "sosna_configs", force: :cascade do |t|
    t.string "key",   limit: 255
    t.string "value", limit: 255
  end

  add_index "sosna_configs", ["key"], name: "index_sosna_configs_on_key", unique: true

  create_table "sosna_penalisations", force: :cascade do |t|
    t.integer  "annual"
    t.integer  "round"
    t.integer  "solver_id"
    t.integer  "score"
    t.text     "title"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "level",      default: "pi", null: false
  end

  add_index "sosna_penalisations", ["solver_id", "annual", "level", "round"], name: "index_sosna_penalisations_on_solver_id_annual_level_round", unique: true

  create_table "sosna_problems", force: :cascade do |t|
    t.string  "title",      limit: 255
    t.integer "annual"
    t.integer "round"
    t.integer "problem_no"
    t.string  "level",                  default: "pi", null: false
  end

  create_table "sosna_results", force: :cascade do |t|
    t.integer  "annual"
    t.integer  "round"
    t.integer  "solver_id"
    t.text     "comment"
    t.integer  "score"
    t.integer  "round_score"
    t.integer  "rank"
    t.integer  "rank_to"
    t.integer  "class_rank"
    t.integer  "class_rank_to"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sosna_results", ["solver_id", "annual", "round"], name: "index_sosna_results_on_solver_id_and_annual_and_round", unique: true

  create_table "sosna_schools", force: :cascade do |t|
    t.text    "name"
    t.text    "short"
    t.text    "street"
    t.text    "num"
    t.text    "city"
    t.text    "psc"
    t.text    "state"
    t.text    "universal_id"
    t.boolean "want_paper",   default: false, null: false
    t.text    "country",      default: "cz"
  end

  create_table "sosna_solutions", force: :cascade do |t|
    t.string   "filename",              limit: 255
    t.string   "filename_orig",         limit: 255
    t.string   "filename_corr",         limit: 255
    t.string   "filename_corr_display", limit: 255
    t.integer  "score"
    t.integer  "problem_id"
    t.integer  "solver_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "has_paper_mail",                    default: false, null: false
  end

  add_index "sosna_solutions", ["solver_id", "problem_id"], name: "index_sosna_solutions_on_solver_id_and_problem_id", unique: true

  create_table "sosna_solvers", force: :cascade do |t|
    t.text     "name"
    t.text     "last_name"
    t.text     "sex",                      default: "male"
    t.text     "birth"
    t.text     "where_to_send",            default: "home"
    t.text     "grade"
    t.text     "grade_num"
    t.text     "finish_year"
    t.text     "annual"
    t.text     "email"
    t.text     "street"
    t.text     "num"
    t.text     "city"
    t.text     "psc"
    t.text     "state"
    t.integer  "user_id"
    t.integer  "school_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "solution_form",            default: "tep"
    t.boolean  "is_test_solver",           default: false,  null: false
    t.text     "country",                  default: "cz"
    t.text     "confirm_state",            default: "none"
    t.string   "how_i_met_pikomat",        default: "",     null: false
    t.string   "how_i_met_pikomat_detail", default: "",     null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "", null: false
    t.string   "encrypted_password",     limit: 255, default: "", null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.string   "confirmation_token",     limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email",      limit: 255
    t.integer  "failed_attempts",                    default: 0
    t.string   "unlock_token",           limit: 255
    t.datetime "locked_at"
    t.integer  "roles_mask"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name",                   limit: 255
    t.string   "last_name",              limit: 255
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end
