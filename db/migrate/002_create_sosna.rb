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

    create_table :sosna_schools do |t|

      t.text :name
      t.text :short

      t.text :street
      t.text :house_num
      t.text :city
      t.text :psc

    end

    create_table :sosna_applicants do |t|

      t.text :name
      t.text :last_name

      t.text :sex
      t.text :birth

      t.text :where_to_send
      t.text :graduation_year
      t.text :school_grade

      t.text :class
      t.text :finish_year

      t.text :email

      t.text :street
      t.text :house_num
      t.text :city
      t.text :psc


      t.belongs_to :user
      t.belongs_to :sosna_school
      t.timestamps
    end
  end

  def self.down
    drop_table :sosna_solutions
    drop_table :sosna_problems
    drop_table :sosna_applicants
    drop_table :sosna_schools
  end
end
