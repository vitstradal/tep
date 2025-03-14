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

ActiveRecord::Schema[7.2].define(version: 29) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "act_event_categories", id: false, force: :cascade do |t|
    t.text "code"
    t.text "name"
    t.bigint "idx", default: 0
    t.boolean "multi_day", default: true
    t.text "description", default: ""
    t.text "visible", default: "ev"
    t.boolean "restrictions_electible", default: true
    t.boolean "mass_spec_electible", default: true
    t.text "activation_needed_default", default: "full"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.index ["code"], name: "idx_350967_index_act_event_categories_on_code", unique: true
  end

  create_table "act_event_invitations", force: :cascade do |t|
    t.bigint "event_id"
    t.bigint "participant_id"
    t.text "chosen", default: "participant"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.index ["event_id", "participant_id"], name: "idx_351019_index_act_event_invitations_on_event_id_and_particip", unique: true
    t.index ["event_id"], name: "idx_351019_index_act_event_invitations_on_event_id"
    t.index ["participant_id"], name: "idx_351019_index_act_event_invitations_on_participant_id"
  end

  create_table "act_event_participants", force: :cascade do |t|
    t.bigint "event_id"
    t.bigint "participant_id"
    t.text "status", default: "yes"
    t.text "note", default: ""
    t.text "place", default: ""
    t.text "participant_info", default: ""
    t.boolean "mass", default: false
    t.text "chosen", default: "none"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.index ["event_id", "participant_id"], name: "idx_351006_index_act_event_participants_on_event_id_and_partici", unique: true
    t.index ["event_id"], name: "idx_351006_index_act_event_participants_on_event_id"
    t.index ["participant_id"], name: "idx_351006_index_act_event_participants_on_participant_id"
  end

  create_table "act_events", force: :cascade do |t|
    t.date "event_start"
    t.date "event_end"
    t.text "title"
    t.text "body"
    t.text "event_category", default: "ot"
    t.text "event_info_url", default: ""
    t.text "event_photos_url", default: ""
    t.text "visible", default: "ev"
    t.boolean "spec_place", default: false
    t.text "spec_place_detail", default: ""
    t.boolean "spec_participant", default: false
    t.boolean "spec_mass", default: false
    t.text "bonz_org", default: ""
    t.boolean "bonz_parent", default: false
    t.boolean "limit_num_participants", default: false
    t.bigint "max_participants", default: 0
    t.boolean "enable_only_specific_participants", default: false
    t.boolean "enable_only_specific_substitutes", default: false
    t.boolean "enable_only_specific_organisers", default: false
    t.boolean "uninvited_participants_dont_see", default: false
    t.boolean "uninvited_organisers_dont_see", default: false
    t.text "activation_needed", default: "full"
    t.boolean "limit_maybe", default: false
    t.date "maybe_deadline"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.text "paper_template", default: "", null: false
  end

  create_table "act_participants", force: :cascade do |t|
    t.bigint "user_id"
    t.text "name"
    t.text "last_name"
    t.text "nickname", default: ""
    t.text "sex", default: "male"
    t.timestamptz "birth"
    t.bigint "grade"
    t.text "address"
    t.text "email"
    t.text "parent_email"
    t.text "phone"
    t.text "parent_phone"
    t.text "eating_habits", default: ""
    t.text "health_problems", default: ""
    t.text "birth_number"
    t.text "health_insurance"
    t.text "activated", default: "full"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
  end

  create_table "informs", force: :cascade do |t|
    t.text "form"
    t.text "data"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.text "user_agent", default: "unknown"
    t.index ["form"], name: "idx_350902_index_informs_on_form"
  end

  create_table "jabbers", force: :cascade do |t|
    t.bigint "user_id"
    t.text "jid"
    t.text "nick"
    t.index ["jid"], name: "idx_350910_index_jabbers_on_jid", unique: true
    t.index ["user_id"], name: "idx_350910_index_jabbers_on_user_id", unique: true
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id"
    t.text "token"
    t.bigint "expires_in"
    t.text "redirect_uri"
    t.timestamptz "created_at"
    t.timestamptz "revoked_at"
    t.text "scopes"
    t.index ["token"], name: "idx_350926_index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id"
    t.text "token"
    t.text "refresh_token"
    t.bigint "expires_in"
    t.timestamptz "revoked_at"
    t.timestamptz "created_at"
    t.text "scopes"
    t.text "previous_refresh_token", default: ""
    t.index ["refresh_token"], name: "idx_350933_index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "idx_350933_index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "idx_350933_index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.text "name"
    t.text "uid"
    t.text "secret"
    t.text "redirect_uri"
    t.text "scopes", default: ""
    t.boolean "confidential", default: true
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.index ["uid"], name: "idx_350917_index_oauth_applications_on_uid", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.text "session_id"
    t.text "data"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.index ["session_id"], name: "idx_350870_index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "idx_350870_index_sessions_on_updated_at"
  end

  create_table "sosna_configs", force: :cascade do |t|
    t.text "key"
    t.text "value"
    t.index ["key"], name: "idx_350847_index_sosna_configs_on_key", unique: true
  end

  create_table "sosna_penalisations", force: :cascade do |t|
    t.bigint "annual"
    t.bigint "round"
    t.bigint "solver_id"
    t.bigint "score"
    t.text "title"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.text "level", default: "pi"
    t.index ["solver_id", "annual", "level", "round"], name: "idx_350877_index_sosna_penalisations_on_solver_id_annual_level_", unique: true
  end

  create_table "sosna_problems", force: :cascade do |t|
    t.text "title"
    t.bigint "annual"
    t.bigint "round"
    t.bigint "problem_no"
    t.text "level", default: "pi"
    t.boolean "updated", default: false, null: false
  end

  create_table "sosna_results", force: :cascade do |t|
    t.bigint "annual"
    t.bigint "round"
    t.bigint "solver_id"
    t.text "comment"
    t.bigint "score"
    t.bigint "round_score"
    t.bigint "rank"
    t.bigint "rank_to"
    t.bigint "class_rank"
    t.bigint "class_rank_to"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.text "level", default: "pi"
    t.index ["solver_id", "annual", "level", "round"], name: "idx_350894_index_sosna_results_on_solver_id_annual_level_round", unique: true
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
    t.boolean "want_paper", default: false
    t.text "country", default: "cz"
  end

  create_table "sosna_solutions", force: :cascade do |t|
    t.text "filename"
    t.text "filename_orig"
    t.text "filename_corr"
    t.text "filename_corr_display"
    t.bigint "score"
    t.bigint "problem_id"
    t.bigint "solver_id"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.boolean "has_paper_mail", default: false
    t.index ["solver_id", "problem_id"], name: "idx_350862_index_sosna_solutions_on_solver_id_and_problem_id", unique: true
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
    t.bigint "user_id"
    t.bigint "school_id"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.text "solution_form", default: "tep"
    t.boolean "is_test_solver", default: false
    t.text "country", default: "cz"
    t.text "confirm_state", default: "none"
    t.text "how_i_met_pikomat", default: ""
    t.text "how_i_met_pikomat_detail", default: ""
  end

  create_table "users", force: :cascade do |t|
    t.text "email", default: ""
    t.text "encrypted_password", default: ""
    t.text "reset_password_token"
    t.timestamptz "reset_password_sent_at"
    t.timestamptz "remember_created_at"
    t.bigint "sign_in_count", default: 0
    t.timestamptz "current_sign_in_at"
    t.timestamptz "last_sign_in_at"
    t.text "current_sign_in_ip"
    t.text "last_sign_in_ip"
    t.text "confirmation_token"
    t.timestamptz "confirmed_at"
    t.timestamptz "confirmation_sent_at"
    t.text "unconfirmed_email"
    t.bigint "failed_attempts", default: 0
    t.text "unlock_token"
    t.timestamptz "locked_at"
    t.bigint "roles_mask"
    t.timestamptz "created_at"
    t.timestamptz "updated_at"
    t.text "name"
    t.text "last_name"
    t.index ["email"], name: "idx_350836_index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "idx_350836_index_users_on_reset_password_token", unique: true
  end
end
