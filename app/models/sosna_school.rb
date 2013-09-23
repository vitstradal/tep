class SosnaSchool < ActiveRecord::Base
  has_many :sosna_solvers
  def address
     "#{street} #{num}, #{psc} #{city}"
  end
end
