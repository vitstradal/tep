class Sosna::Penalisation < ActiveRecord::Base
  include ApplicationHelper
  belongs_to :solver
end
