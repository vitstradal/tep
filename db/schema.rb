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

ActiveRecord::Schema.define(version: 24) do

  create_table "act_event_categories", id: false, force: :cascade do |t|
    t.string "code", limit: 2
    t.string "name"
    t.integer "idx", default: 0
    t.boolean "multi_day", default: true
    t.text "description", default: ""
    t.string "visible", default: "ev"
    t.boolean "restrictions_electible", default: true
    t.boolean "mass_spec_electible", default: true
    t.string "activation_needed_default", default: "full"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["code"], name: "index_act_event_categories_on_code", unique: true
  end

  create_table "act_event_invitations", force: :cascade do |t|
    t.integer "event_id"
    t.integer "participant_id"
    t.string "chosen", default: "participant"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["event_id", "participant_id"], name: "index_act_event_invitations_on_event_id_and_participant_id", unique: true
    t.index ["event_id"], name: "index_act_event_invitations_on_event_id"
    t.index ["participant_id"], name: "index_act_event_invitations_on_participant_id"
  end

  create_table "act_event_participants", force: :cascade do |t|
    t.integer "event_id"
    t.integer "participant_id"
    t.string "status", default: "yes"
    t.string "note", default: ""
    t.string "place", default: ""
    t.string "participant_info", default: ""
    t.boolean "mass", default: false
    t.string "chosen", default: "none"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["event_id", "participant_id"], name: "index_act_event_participants_on_event_id_and_participant_id", unique: true
    t.index ["event_id"], name: "index_act_event_participants_on_event_id"
    t.index ["participant_id"], name: "index_act_event_participants_on_participant_id"
  end

  create_table "act_events", force: :cascade do |t|
    t.date "event_start"
    t.date "event_end"
    t.string "title"
    t.text "body"
    t.string "event_category", default: "ot"
    t.string "event_info_url", default: ""
    t.string "event_photos_url", default: ""
    t.string "visible", default: "ev"
    t.boolean "spec_place", default: false
    t.string "spec_place_detail", default: ""
    t.boolean "spec_participant", default: false
    t.boolean "spec_mass", default: false
    t.string "bonz_org", default: ""
    t.boolean "bonz_parent", default: false
    t.boolean "limit_num_participants", default: false
    t.integer "max_participants", default: 0
    t.boolean "enable_only_specific_participants", default: false
    t.boolean "enable_only_specific_substitutes", default: false
    t.boolean "enable_only_specific_organisers", default: false
    t.boolean "uninvited_participants_dont_see", default: false
    t.boolean "uninvited_organisers_dont_see", default: false
    t.string "activation_needed", default: "full"
    t.boolean "limit_maybe", default: false
    t.date "maybe_deadline"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "act_participants", force: :cascade do |t|
    t.integer "user_id"
    t.string "name"
    t.string "last_name"
    t.string "nickname", default: ""
    t.string "sex", default: "male"
    t.datetime "birth"
    t.integer "grade"
    t.string "address"
    t.string "email"
    t.string "parent_email"
    t.string "phone"
    t.string "parent_phone"
    t.text "eating_habits", default: ""
    t.text "health_problems", default: ""
    t.text "birth_number"
    t.string "health_insurance"
    t.string "activated", default: "full"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "informs", force: :cascade do |t|
    t.string "form", limit: 255
    t.string "data", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "user_agent", default: "unknown"
    t.index ["form"], name: "index_informs_on_form"
  end

  create_table "jabbers", force: :cascade do |t|
    t.integer "user_id"
    t.text "jid"
    t.text "nick"
    t.index ["jid"], name: "index_jabbers_on_jid", unique: true
    t.index ["user_id"], name: "index_jabbers_on_user_id", unique: true
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer "resource_owner_id", null: false
    t.integer "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer "resource_owner_id"
    t.integer "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", limit: 255, null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "sosna_configs", force: :cascade do |t|
    t.string "key", limit: 255
    t.string "value", limit: 255
    t.index ["key"], name: "index_sosna_configs_on_key", unique: true
  end

  create_table "sosna_penalisations", force: :cascade do |t|
    t.integer "annual"
    t.integer "round"
    t.integer "solver_id"
    t.integer "score"
    t.text "title"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "level", default: "pi", null: false
    t.index ["solver_id", "annual", "level", "round"], name: "index_sosna_penalisations_on_solver_id_annual_level_round", unique: true
  end

  create_table "sosna_problems", force: :cascade do |t|
    t.string "title", limit: 255
    t.integer "annual"
    t.integer "round"
    t.integer "problem_no"
    t.string "level", default: "pi", null: false
  end

  create_table "sosna_results", force: :cascade do |t|
    t.integer "annual"
    t.integer "round"
    t.integer "solver_id"
    t.text "comment"
    t.integer "score"
    t.integer "round_score"
    t.integer "rank"
    t.integer "rank_to"
    t.integer "class_rank"
    t.integer "class_rank_to"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "level", default: "pi", null: false
    t.index ["solver_id", "annual", "level", "round"], name: "index_sosna_results_on_solver_id_annual_level_round", unique: true
  end

  create_table "sosna_schools", force: :cascade do |t|
    t.text "name"
    t.text "short"
    t.text "street"
    t.text "num"
    t.text "city"
    t.text "psc"
    t.text "state"
    t.text "universal_id"
    t.boolean "want_paper", default: false, null: false
    t.text "country", default: "cz"
  end

  create_table "sosna_solutions", force: :cascade do |t|
    t.string "filename", limit: 255
    t.string "filename_orig", limit: 255
    t.string "filename_corr", limit: 255
    t.string "filename_corr_display", limit: 255
    t.integer "score"
    t.integer "problem_id"
    t.integer "solver_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "has_paper_mail", default: false, null: false
    t.index ["solver_id", "problem_id"], name: "index_sosna_solutions_on_solver_id_and_problem_id", unique: true
  end

  create_table "sosna_solvers", force: :cascade do |t|
    t.text "name"
    t.text "last_name"
    t.text "sex", default: "male"
    t.text "birth"
    t.text "where_to_send", default: "home"
    t.text "grade"
    t.text "grade_num"
    t.text "finish_year"
    t.text "annual"
    t.text "email"
    t.text "street"
    t.text "num"
    t.text "city"
    t.text "psc"
    t.text "state"
    t.integer "user_id"
    t.integer "school_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "solution_form", default: "tep"
    t.boolean "is_test_solver", default: false, null: false
    t.text "country", default: "cz"
    t.text "confirm_state", default: "none"
    t.string "how_i_met_pikomat", default: "", null: false
    t.string "how_i_met_pikomat_detail", default: "", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", limit: 255, default: "", null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email", limit: 255
    t.integer "failed_attempts", default: 0
    t.string "unlock_token", limit: 255
    t.datetime "locked_at"
    t.integer "roles_mask"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name", limit: 255
    t.string "last_name", limit: 255
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
