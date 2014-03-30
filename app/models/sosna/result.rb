class Sosna::Result < ActiveRecord::Base
  include SosnaHelper
  belongs_to :solver

  def rank_multi?
    return false if rank.nil? || rank_to.nil?
    return rank < rank_to
  end

  def class_rank_multi?
    return false if class_rank.nil? || class_rank_to.nil?
    return class_rank < class_rank_to
  end
end
