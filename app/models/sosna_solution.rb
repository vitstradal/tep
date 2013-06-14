class SosnaSolution < ActiveRecord::Base
  belongs_to :sosna_applicant
  belongs_to :sosna_problem
end
