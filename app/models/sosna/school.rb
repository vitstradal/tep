class Sosna::School < ActiveRecord::Base
  has_many :solvers
  def address
     "#{street} #{num}, #{psc} #{city}"
  end
end
