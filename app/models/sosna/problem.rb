##
# Třída reprezentující tabulku sosna_problem, úloha v sérii
#
# *Colums*
#      t.string  "title",      limit: 255
#      t.integer "annual"
#      t.integer "round"
#      t.integer "problem_no"

class Sosna::Problem < ActiveRecord::Base
  has_many :solutions

  BONUS_ROUND_NUM = 100
  BONUS_PROBLEM_NUM = 100

  ##
  # 
  # *Returns* počet serií v ročníku tohoto problému
  def rounds
    _rounds_roc(annual)
  end

  ##
  # *Returns* `problem_no` (1,2,...) ale v případě bonusové úlohy ('B', 'B2', ...)
  # bonusová úloha se pozná tak, že `problem_no` je 100, nebo více
  def short_name
    return problem_no if problem_no < BONUS_ROUND_NUM
    return 'B' if problem_no == BONUS_ROUND_NUM
    return 'B' + (problem_no - BONUS_ROUND_NUM).to_s
  end
  def bonus?
    return problem_no >= BONUS_ROUND_NUM
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
