class Sosna::Penalisation < ActiveRecord::Base
  include SosnaHelper
  belongs_to :solver
end
