require 'pp'
class SosnaController < ApplicationController

  
  def id_problem_hash(arr)
    ret = {}
    arr.each { |item|  ret[item.sosna_problem_id] = item }
    #logger.fatal "hash:" + ret.inspect
    return ret
  end


  def load_config
    @config  =  {annual:20, round: 1}
    SosnaConfig.all.each {|c| @config[c.key.to_sym] =  c.value}
  end
end
