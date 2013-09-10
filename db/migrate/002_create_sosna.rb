class CreateSosna < ActiveRecord::Migration
  def self.up

    create_table :sosna_configs do |t|
      t.string :key
      t.string :value
    end
    add_index :sosna_configs, :key, unique: true
    create_table :sosna_problems do |t|
      t.string :title
      t.integer :annual # ročník
      t.integer :round
      t.integer :problem_no
    end

    create_table :sosna_solutions do |t|
      t.string  :filename
      t.string  :orig_filename
      t.integer :score
      t.belongs_to :sosna_problem
      t.belongs_to :sosna_solver
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

    create_table :sosna_solvers do |t|

      t.text :name
      t.text :last_name

      t.text :sex, :default=> 'male'
      t.text :birth

      t.text :where_to_send,  default: 'home'

      t.text :grade,       default: '111'
      t.text :finish_year, default: '2000'
      t.text :annual

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
    drop_table :sosna_solvers
    drop_table :sosna_schools
  end
end
