##
# Třída reprezentující tabulku sosna_solution, řešení uživatele (každý jedne papír)
#
# *Colums*
#    t.string   "filename",              limit: 255
#    t.string   "filename_orig",         limit: 255
#    t.string   "filename_corr",         limit: 255
#    t.string   "filename_corr_display", limit: 255
#    t.integer  "score"
#    t.integer  "problem_id"
#    t.integer  "solver_id"
#    t.datetime "created_at"
#    t.datetime "updated_at"
#    t.boolean  "has_paper_mail",                    default: false, null: false
class Sosna::Solution < ActiveRecord::Base

  #fixme: helpery asi nepatri do modelu, ale tady se poziva 'translit', tak so  stim?
  include ApplicationHelper

  belongs_to :solver
  belongs_to :problem
  def owner?(user)
    return false if solver.user.nil?
    return solver.user.id == user.id
  end


  ##
  # *Returns* název souboru řešení (originál) na disku / nil
  def get_filename_ori
    _get_filename(true)
  end

  ##
  # *Returns* název souboru opraveného řešení na disku / nil
  def get_filename_rev
    _get_filename(false)
  end

  ##
  # *Returns* podadresář v uploads pro daný ročník/level/sérii,
  # např. "rocnik40/serie01", pro juniory "rocnik40-jr/serie01"
  def self.subdir_for(annual, level, round)
    suffix = (level.nil? || level.empty? || level == Sosna::Solver::NORMAL_LEVEL) ? '' : "-#{level}"
    'rocnik%02i%s/serie%02i' % [annual.to_i, suffix, round.to_i]
  end

  ##
  # *Returns* podadresář v uploads pro toto řešení (viz subdir_for)
  def subdir
    self.class.subdir_for(problem.annual, problem.level, problem.round)
  end

  ##
  # *Returns* cesta k souboru řešení (originál) relativní k uploads adresáři
  def path_ori
    "#{subdir}/#{get_filename_ori}"
  end

  ##
  # *Returns* cesta k souboru opraveného řešení relativní k uploads adresáři
  def path_rev
    "#{subdir}/#{get_filename_rev}"
  end

  private

  def _get_filename(is_ori)
     roc = problem.annual
     se = problem.round
     ul = problem.problem_no
     level = problem.level
     level_ext = Sosna::Solver::level_extension(level)
     rel_id = solver_id
     last, name = "LAST", "NAME"
     last = translit  solver.last_name if solver
     name = translit solver.name if solver
     typ = is_ori ? 'ori' : 'rev'
     #Rails.logger.fatal "name:" + solver.name
     #Rails.logger.fatal "nametr:" + name
     'reseni-roc%02i%s-se%02i-ul%i-rel%03i-%s-%s-%s.pdf'  % [ roc, level_ext, se, ul, rel_id, typ, last, name ]
  end
end
