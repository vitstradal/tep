class Sosna::Result < ActiveRecord::Base
  include SosnaHelper
  belongs_to :solver
end
