class Sosna::School < ActiveRecord::Base
  has_many :solvers
  validates :name, :psc, :city, presence: true
  #validates_uniqueness_of :short
  def address
     "#{street} #{num}, #{psc} #{city}"
  end

  def long
     "#{name}, #{street} #{num}, #{psc} #{city}"
  end
end
