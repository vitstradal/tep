require 'json'
require 'faraday'

MARVIN_TOKEN= "1ibw97coqfb5ijpsoiygb3fmmc"
PIKOMAT_TEAM= "r8abo1qw1jd5xggu89t88m8pta"
KLEP_API = '/klep/api/v4'

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
      resp = conn.get( "#{KLEP_API}/users/username/#{klep_username}")

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

    teams    = JSON.parse(conn.get( "#{KLEP_API}/users/#{klep_user_id}/teams/unread").body)
    channels = JSON.parse(conn.get( "#{KLEP_API}/users/#{klep_user_id}/teams/#{PIKOMAT_TEAM}/channels").body)
    members  = JSON.parse(conn.get( "#{KLEP_API}/users/#{klep_user_id}/teams/#{PIKOMAT_TEAM}/channels/members").body)

    # channels: [ { id: "", total_msg_count : ..., type : "D" } , ... ]
    # members:  [ { chanel_id: "", user_id: "", msg_count : ... } , ... ]
    #return render :json => {:members => members, :channels => channels }

    members_msg_count_by_channel_id = members.reduce({}) do
       |ret,member|
       ret[member['channel_id']] = member['msg_count']
       ret
    end

    channels_count_by_channel_id = channels.reduce({}) do
       |ret,channel|
       ret[channel['id']] = channel['total_msg_count'] if channel['type'] == 'D'
       ret
    end
    channels_count = 0;
    channels_count_by_channel_id.each do
      |channel_id, total_msg_count|
      member_msg_count = members_msg_count_by_channel_id[channel_id]
      if !member_msg_count.nil?  && total_msg_count > member_msg_count
          channels_count += 1
      end
    end
    msg_count =  teams[0]['msg_count'] + channels_count
    mention_count =  teams[0]['mention_count']
    session[:klep_msg_count] = msg_count
    render :json => { :msg_count => msg_count }
  rescue Exception => e
    render :json => { msg_count: 0,  mention_count: 0, err: e.to_s, trace: e.backtrace}
  end
end
