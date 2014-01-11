class Sosna::Solution < ActiveRecord::Base
  include SosnaHelper
  belongs_to :solver
  belongs_to :problem
  def owner?(user)
    return solver.user.id == user.id
  end

  def get_filename(is_corr = false)
     roc = problem.annual
     se = problem.round
     ul = problem.problem_no
     rel_id = solver.id
     last = translit  solver.last_name
     name = translit solver.name
     typ = is_corr ? 'rev' : 'ori'
     #Rails.logger.fatal "name:" + solver.name
     #Rails.logger.fatal "nametr:" + name
     'reseni-roc%02i-se%02i-ul%i-rel%03i-%s-%s-%s.pdf'  % [ roc, se, ul, rel_id, typ, last, name ]
  end

end
