class Sosna::Result < ActiveRecord::Base
  include SosnaHelper
  belongs_to :solver

  def rank_multi?
    return rank < rank_to
  end

  def class_rank_multi?
    return class_rank < class_rank_to
  end
end
