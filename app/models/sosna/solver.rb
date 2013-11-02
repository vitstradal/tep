class Sosna::Solver < ActiveRecord::Base
  has_many :solutions
  belongs_to :school
  belongs_to :user

  validates :name, :last_name, :num, :city, presence: true

  #validates_associated :sosna_school
  def full_name
     "#{name} #{last_name}"
  end 
  def address
     "#{street} #{num}, #{psc} #{city}"
  end
end
