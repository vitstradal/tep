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
    Sosna::Config.all.load.each {|c| @config[c.key.to_sym] =  c.value}
    @annual = @config[:annual]
    @round = @config[:round]
  end

  def get_sorted_solvers(annual)
      solvers = Sosna::Solver.includes(:school).where(annual: annual).load 
      solvers.sort! { |a,b| (a.last_name != b.last_name ) ? strcoll(a.last_name, b.last_name) :
                                                            strcoll(a.name, b.name)
                    }
      solvers.sort! { |a,b| strcollf(a.last_name, b.last_name) || strcollf(a.name, b.name) || 0 }
  end
end
