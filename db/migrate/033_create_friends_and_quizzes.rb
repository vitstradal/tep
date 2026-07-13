##
# Kvízy, adventomat a přátelé Pikomatu — viz navrh-kvizy-a-pratele.md
class CreateFriendsAndQuizzes < ActiveRecord::Migration[7.2]
  def change
    create_table :friends do |t|
      t.text :uuid, null: false
      t.text :nick, null: false
      t.bigint :user_id
      t.boolean :hidden, default: false
      t.timestamptz :last_seen_at
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :friends, :uuid, unique: true
    add_index :friends, :user_id, unique: true

    create_table :quizzes do |t|
      t.text :name, null: false
      t.text :quiz_type
      t.text :subtype
      t.text :title
      t.date :opens_on
      t.date :closes_on
      t.jsonb :data
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :quizzes, :name, unique: true

    create_table :quiz_answers do |t|
      t.bigint :quiz_id, null: false
      t.bigint :friend_id, null: false
      t.integer :question_no
      t.text :answer
      t.jsonb :data
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :quiz_answers, [:quiz_id, :question_no, :friend_id], unique: true
  end
end
