class SosnaSolver < ActiveRecord::Base
  has_many :sosna_solutions
  belongs_to :sosna_school
  validates :name, :last_name, :city, presence: true
  #validates_associated :sosna_school
  def address
     "#{street} #{house_num}, #{psc} #{city}"
  end
end
