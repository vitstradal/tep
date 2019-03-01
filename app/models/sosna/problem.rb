##
# Třída reprezentující tabulku sosna_problem, úloha v sérii
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
class Sosna::Problem < ActiveRecord::Base
  has_many :solutions

  BONUS_ROUND_NUM = 100

  ##
  # 
  # *Returns* počet serií v ročníku tohoto problému
  def rounds
    _rounds_roc(annual)
  end


  private
  def _rounds_roc(annual)
    return Sosna::Problem.select('round')
                       .where({annual: annual})
                       .group('round')
                       .order('round')
                       .all
                       .map do |ul|
                          _round_link(roc, ul.round)
                       end

  end
end
