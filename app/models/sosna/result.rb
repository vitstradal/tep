class Sosna::Result < ActiveRecord::Base

  belongs_to :solver

  def rank_multi?
    return false if rank.nil? || rank_to.nil?
    return rank < rank_to
  end

  def class_rank_multi?
    return false if class_rank.nil? || class_rank_to.nil?
    return class_rank < class_rank_to
  end

  def rank_disp(last_result = nil)
     return rank_disp if last_result.nil?
     return rank if last_result.rank != rank
     return ''
  end

  def rank_range(result_last = nil)
    range = rank_multi? ? "#{result.rank}-#{result.rank_to}" : result.rank
    return range if result_last.nil?
    range_last = last_result.rank_range
    return range if range != range_last
    return ''
  end
  
  def class_rank_range(result_last = nil)
    class_range = class_rank_multi? ? "#{result.class_rank}-#{result.class_rank_to}" : result.class_rank
    return class_range if result_last.nil?
    class_range_last = last_result.class_rank_range
    return class_range if class_range != class_range_last
    return ''
  end

  def class_rank_range
    class_rank_multi? ? "#{result.class_rank}-#{result.class_rank_to}" : result.class_rank
  end
end
