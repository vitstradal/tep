class Sosna::School < ActiveRecord::Base
  has_many :solvers
  validates :name, :num, :psc, :city, presence: true
  def address
     "#{street} #{num}, #{psc} #{city}"
  end
end
