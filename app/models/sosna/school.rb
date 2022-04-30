##
# Třída reprezentující tabulku sosna_school, školu
#
# *Colums*
#    t.text    "name"
#    t.text    "short"
#    t.text    "street"
#    t.text    "num"
#    t.text    "city"
#    t.text    "psc"
#    t.text    "state"
#    t.text    "universal_id"
#    t.boolean "want_paper",   default: false, null: false
#    t.text    "country",      default: "cz"
class Sosna::School < ActiveRecord::Base
  has_many :solvers
  validates :name, :psc, :city, presence: true
  #validates_uniqueness_of :short

  ##
  # *Returns* adresa zkombinovana z ostatních položek "#{street} #{num}, #{psc} #{city}"
  def address
     "#{street} #{num}, #{psc} #{city}"
  end

  ##
  # *Returns* zkracene jmeno na 20 znaku
#  def name_short
#
#    namep[0..19]
#  end

  ##
  # *Returns* dlouha adresa adresa zkombinovana z ostatních položek "#{city}, #{name}, #{street} #{num}, #{psc} "
  def long
     "#{city}, #{name}, #{street} #{num}, #{psc} "
  end
end
