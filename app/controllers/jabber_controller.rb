require 'simple_crypt'

class JabberController < ApplicationController
  authorize_resource
  include ApplicationHelper

  def update
    params.require(:jabber).permit!
    jabber = Jabber.find(params[:id])
    jabber.update_attributes(params[:jabber])
    redirect_to  user_show_path(jabber.user_id, 'jabber')
  end

  def new
    user_id = params[:user_id]
    user = User.find(user_id)
    jabber = Jabber.new(user_id: user_id)
    nick = user.email.split('@', 2)[0]
    i = ''
    begin 
      jid = "#{nick}#{i}@pikomat.mff.cuni.cz"
      i = i == '' ? 2 : i+1
    end while !Jabber.find_by_jid(jid).nil?

    jabber.nick = nick
    jabber.jid = jid
    jabber.save
    redirect_to  user_show_path(user_id, 'jabber')
  end
  def preauth
    rid = session[:jabber_rid]
    sid = session[:jabber_sid]
    render :json => {status: 'ok', rid: rid, sid: sid }
  end

  def auth
     jid = params[:jid]
     password = params[:password]
     key = Rails.configuration.jabber_secret
     domain = Rails.configuration.jabber_domain
     begin
       password = SimpleCrypt.decrypt(password, key) 
     rescue OpenSSL::Cipher::CipherError => e
       return render :json => { status: "error", msg: 'dcr' }
     end
     jabber = Jabber.find_by_jid("#{jid}@#{domain}")
     return render :json => { status: "error", msg: 'noj'} if jabber.nil?
     user = jabber.user
     return render :json => { status: "error", msg: 'nou'} if user.nil?
     return render :json => { status: "error", msg: 'bad'} if ! user.valid_password? password
     render :json => { status: "ok"}
  end

  def delete
    jabber = Jabber.find(params[:id])
    user_id =  jabber.user.id
    jabber.destroy
    redirect_to  user_show_path(user_id, 'jabber')
  end
end
