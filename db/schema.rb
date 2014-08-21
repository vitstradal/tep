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

ActiveRecord::Schema.define(version: 11) do

  create_table "sessions", force: true do |t|
    t.string   "session_id", null: false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", unique: true
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at"

  create_table "sosna_configs", force: true do |t|
    t.string "key"
    t.string "value"
  end

  add_index "sosna_configs", ["key"], name: "index_sosna_configs_on_key", unique: true

  create_table "sosna_penalisations", force: true do |t|
    t.integer  "annual"
    t.integer  "round"
    t.integer  "solver_id"
    t.integer  "score"
    t.text     "title"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sosna_penalisations", ["solver_id", "annual", "round"], name: "index_sosna_penalisations_on_solver_id_and_annual_and_round", unique: true

  create_table "sosna_problems", force: true do |t|
    t.string  "title"
    t.integer "annual"
    t.integer "round"
    t.integer "problem_no"
  end

  create_table "sosna_results", force: true do |t|
    t.integer  "annual"
    t.integer  "round"
    t.integer  "solver_id"
    t.text     "comment"
    t.integer  "score"
    t.integer  "round_score"
    t.text     "rank"
    t.text     "rank_to"
    t.text     "class_rank"
    t.text     "class_rank_to"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sosna_results", ["solver_id", "annual", "round"], name: "index_sosna_results_on_solver_id_and_annual_and_round", unique: true

  create_table "sosna_schools", force: true do |t|
    t.text "name"
    t.text "short"
    t.text "street"
    t.text "num"
    t.text "city"
    t.text "psc"
    t.text "state"
    t.text "universal_id"
  end

  create_table "sosna_solutions", force: true do |t|
    t.string   "filename"
    t.string   "filename_orig"
    t.string   "filename_corr"
    t.string   "filename_corr_display"
    t.integer  "score"
    t.integer  "problem_id"
    t.integer  "solver_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "has_paper_mail",        default: false, null: false
  end

  add_index "sosna_solutions", ["solver_id", "problem_id"], name: "index_sosna_solutions_on_solver_id_and_problem_id", unique: true

  create_table "sosna_solvers", force: true do |t|
    t.text     "name"
    t.text     "last_name"
    t.text     "sex",            default: "male"
    t.text     "birth"
    t.text     "where_to_send",  default: "home"
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
    t.text     "solution_form",  default: "tep"
    t.boolean  "is_test_solver", default: false,  null: false
  end

  create_table "users", force: true do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",        default: 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.integer  "roles_mask"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.string   "last_name"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end
