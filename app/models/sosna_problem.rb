class SosnaProblem < ActiveRecord::Base
  has_many :sosna_solutions
  def rounds
    _rounds_roc(annual)
  end

  def _rounds_roc(annual)
    return SosnaProblem.select('round')
                       .where({annual: annual})
                       .group('round')
                       .order('round')
                       .all
                       .map do |ul|
                          _round_link(roc, ul.round)
                       end

  end
end
