class Sosna::Solution < ActiveRecord::Base

  #fixme: helpery asi nepatri do modelu, ale tady se poziva 'translit', tak so  stim?
  include ApplicationHelper

  belongs_to :solver
  belongs_to :problem
  def owner?(user)
    return false if solver.user.nil?
    return solver.user.id == user.id
  end


  def get_filename_ori
    _get_filename(true)
  end

  def get_filename_rev
    _get_filename(false)
  end

  private

  def _get_filename(is_ori)
     roc = problem.annual
     se = problem.round
     ul = problem.problem_no
     rel_id = solver_id
     last, name = "LAST", "NAME"
     last = translit  solver.last_name if solver
     name = translit solver.name if solver
     typ = is_ori ? 'ori' : 'rev'
     #Rails.logger.fatal "name:" + solver.name
     #Rails.logger.fatal "nametr:" + name
     'reseni-roc%02i-se%02i-ul%i-rel%03i-%s-%s-%s.pdf'  % [ roc, se, ul, rel_id, typ, last, name ]
  end

end
