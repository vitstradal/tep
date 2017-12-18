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

#  def rank_disp(result_last = nil, page_begin = false)
#     return rank_disp if result_last.nil?
#     return rank if page_begin || result_last.rank != rank
#     return ''
#  end

  def rank_range(result_last = nil, page_begin = false)
    range = rank_multi? ? "#{rank}.--#{rank_to}." : "#{rank}."
    return range if result_last.nil?
    range_last = result_last.rank_range
    return range if page_begin || range != range_last
    return ''
  end
  
  def class_rank_range(result_last = nil,page_begin = false)
    class_range = class_rank_multi? ? "#{class_rank}.--#{class_rank_to}." : "#{class_rank}."
    return class_range if result_last.nil?
    class_range_last = result_last.class_rank_range
    return class_range if page_begin || class_range != class_range_last
    return ''
  end

end
