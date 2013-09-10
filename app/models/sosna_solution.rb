class SosnaSolution < ActiveRecord::Base
  belongs_to :sosna_solver
  belongs_to :sosna_problem
  def owner?(user)
    return  sosna_solver.user.id == user.id
  end
end
