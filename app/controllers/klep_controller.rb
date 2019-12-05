require 'json'
require 'faraday'

MARVIN_TOKEN= "1ibw97coqfb5ijpsoiygb3fmmc"
PIKOMAT_TEAM= "r8abo1qw1jd5xggu89t88m8pta"

class KlepController < ApplicationController
  include ApplicationHelper

  # ret:
  # { err : "no such user" } kdyz neni registrovany v klepu
  # { msg_count: 33, mention_count: 33 }
  # {} kdyz neni prihlaseny nebo neni org (nemelo by nastat)
  def status
    return render :json => {} if  current_user.nil? || !current_user.org?

    conn = Faraday.new(:url => "https://pikomat.mff.cuni.cz", ssl: { verify: false } )
    conn.authorization :Bearer, MARVIN_TOKEN

    if ! session.has_key?(:klep_user_id)
      klep_username = current_user.email.sub('@','-')
      resp = conn.get( "/klep/api/v4/users/username/#{klep_username}")

      data = JSON.parse(resp.body)
      if  data.nil? || !data.has_key?('id')  || data.has_key?('message')
        session[:klep_user_id] = nil
        return render :json => {:err => "no such user"}
      end

      klep_user_id = session[:klep_user_id] = data['id']

    else
      klep_user_id = session[:klep_user_id]
      return render :json => {:err => "no such user"} if klep_user_id.nil?
    end

    #resp = conn.get( "/klep/api/v4/users/#{klep_user_id}/teams/#{PIKOMAT_TEAM}/unread")
    resp = conn.get( "/klep/api/v4/users/#{klep_user_id}/teams/unread")
    data = JSON.parse(resp.body)
    #msg_count =  data['msg_count']
    msg_count =  data[0]['msg_count']
    mention_count =  data[0]['mention_count']
    session[:klep_msg_count] = msg_count
    render :json => { :msg_count => msg_count,  :mention_count => mention_count}
  end
end
