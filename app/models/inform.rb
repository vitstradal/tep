require 'json'
##
# Třída reprezentující tabulku inform
#
# *Colums*
#    t.string   "form",       limit: 255
#    t.string   "data",       limit: 255
#    t.datetime "created_at"
#    t.datetime "updated_at"
#    t.text     "user_agent",             default: "unknown"
class Inform < ActiveRecord::Base
  attr_accessor :rest
  ##
  # decoduje json sloupec `data`
  def jdata
    @jdata = JSON.parse(data) if @jdata.nil?
    @jdata
  end
end

