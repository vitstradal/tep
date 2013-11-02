class Sosna::Solution < ActiveRecord::Base
  belongs_to :solver
  belongs_to :problem
  def owner?(user)
    return solver.user.id == user.id
  end
end
