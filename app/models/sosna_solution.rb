class SosnaSolution < ActiveRecord::Base
  belongs_to :sosna_solver
  belongs_to :sosna_problem
end
