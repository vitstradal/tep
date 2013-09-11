require 'pp'
class SosnaController < ApplicationController

  authorize_resource

  before_filter do 
    load_config
    params[:se] ||= @round
    params[:roc] ||= @annual
    #params[:ul]
  end
  
  def id_problem_hash(arr)
    ret = {}
    arr.each { |item|  ret[item.sosna_problem_id] = item }
    #logger.fatal "hash:" + ret.inspect
    return ret
  end


  def load_config
    @config  =  {annual:20, round: 1}
    SosnaConfig.all.each {|c| @config[c.key.to_sym] =  c.value}
    @annual = @config[:annual]
    @round = @config[:round]
  end
end
