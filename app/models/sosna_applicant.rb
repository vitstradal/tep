class SosnaApplicant < ActiveRecord::Base
  has_many :sosna_solutions
  belongs_to :sosna_school
  validates :name, :last_name, :city, presence: true
  validates_associated :sosna_school
end
