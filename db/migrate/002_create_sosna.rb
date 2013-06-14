class CreateSosna < ActiveRecord::Migration
  def self.up

    create_table :sosna_problems do |t|
      t.string :title
      t.integer :year
      t.integer :round
      t.integer :problem_no
    end

    create_table :sosna_solutions do |t|
      t.string  :filename
      t.string  :orig_filename
      t.integer :score
      t.belongs_to :sosna_problem
      t.belongs_to :sosna_applicant
      t.timestamps
    end

    create_table :sosna_applicants do |t|
      t.text :name
      t.text :address
      t.belongs_to :user
      t.timestamps
    end
  end

  def self.down
    drop_table :sosna_solutions
    drop_table :sosna_problems
    drop_table :sosna_applicants
  end
end
