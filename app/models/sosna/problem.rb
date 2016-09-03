class Sosna::Problem < ActiveRecord::Base
  has_many :solutions

  BONUS_ROUND_NUM = 100

  def rounds
    _rounds_roc(annual)
  end


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
