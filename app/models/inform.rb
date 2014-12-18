require 'json'
class Inform < ActiveRecord::Base
  def jdata
    @jdata = JSON.parse(data) if @jdata.nil?
    @jdata
  end
end

