class CreateSosna < ActiveRecord::Migration
  def self.up

    create_table :sosna_configs do |t|
      t.string :key
      t.string :value
    end
    add_index :sosna_configs, :key, unique: true

    create_table :sosna_problems do |t|
      t.string  :title
      t.integer :annual     # ročník
      t.integer :round      # serie
      t.integer :problem_no # uloha
    end

    create_table :sosna_solutions do |t|
      t.string  :filename
      t.string  :filename_orig

      t.string  :filename_corr
      t.string  :filename_corr_display

      t.integer :score
      t.belongs_to :problem
      t.belongs_to :solver
      t.timestamps
    end

    create_table :sosna_schools do |t|

      t.text :name
      t.text :short

      t.text :street
      t.text :num
      t.text :city
      t.text :psc
      t.text :state

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
      t.text :num
      t.text :city
      t.text :psc
      t.text :state

      t.belongs_to :user
      t.belongs_to :school
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
