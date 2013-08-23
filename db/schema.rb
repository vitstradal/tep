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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 2) do

  create_table "sosna_applicants", :force => true do |t|
    t.text     "name"
    t.text     "last_name"
    t.text     "sex"
    t.text     "birth"
    t.text     "where_to_send"
    t.text     "graduation_year"
    t.text     "school_grade"
    t.text     "class"
    t.text     "finish_year"
    t.text     "email"
    t.text     "street"
    t.text     "house_num"
    t.text     "city"
    t.text     "psc"
    t.integer  "user_id"
    t.integer  "sosna_school_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sosna_problems", :force => true do |t|
    t.string  "title"
    t.integer "year"
    t.integer "round"
    t.integer "problem_no"
  end

  create_table "sosna_schools", :force => true do |t|
    t.text "name"
    t.text "short"
    t.text "street"
    t.text "house_num"
    t.text "city"
    t.text "psc"
  end

  create_table "sosna_solutions", :force => true do |t|
    t.string   "filename"
    t.string   "orig_filename"
    t.integer  "score"
    t.integer  "sosna_problem_id"
    t.integer  "sosna_applicant_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "email",                                 :default => "", :null => false
    t.string   "encrypted_password",     :limit => 128, :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                         :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.integer  "roles_mask"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
