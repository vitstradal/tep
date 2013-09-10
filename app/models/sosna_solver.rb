class SosnaSolver < ActiveRecord::Base
  has_many :sosna_solutions
  belongs_to :sosna_school
  belongs_to :user
  validates :name, :last_name, :city, presence: true
  #validates_associated :sosna_school
  def full_name
     "#{name} #{last_name}"
  end 
  def address
     "#{street} #{house_num}, #{psc} #{city}"
  end
end
