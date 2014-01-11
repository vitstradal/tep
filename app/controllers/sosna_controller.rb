require 'pp'
class SosnaController < ApplicationController

  authorize_resource

  before_filter do
    load_config
  end

  def id_problem_hash(arr)
    ret = {}
    arr.each { |item|  ret[item.problem_id] = item }
    #logger.fatal "hash:" + ret.inspect
    return ret
  end


  def load_config
    @config  =  { annual:20,
                  round: 1,
                  show_revisions: 'no',
                }
    Sosna::Config.all.each {|c| @config[c.key.to_sym] =  c.value}
    @annual = @config[:annual]
    @round = @config[:round]
  end
  def get_sorted_solvers(annual)
      solvers = Sosna::Solver.where(annual: annual).all 
      solvers.sort! { |a,b| (a.last_name != b.last_name ) ? FFILocale::strcoll(a.last_name, b.last_name) :
                                                             FFILocale::strcoll(a.name, b.name)
                     }
  end
end
