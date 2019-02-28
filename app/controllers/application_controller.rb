require 'simple_bosh_session'

##
# Controller od kterého se odvozují ostatní kotrolery v tepu.
#
# Je jednak kvůli řešení errorů (generuje se error_id, a zasílá se mail).
# Druhý důvod je `after_sign_in_path_for` hook kam se přesměrovat po nalohování
#

class ApplicationController < ActionController::Base
  protect_from_forgery

  include ApplicationHelper

  ##
  # po nalogování se přesměru na URL danou parametrem `next`
  def after_sign_in_path_for(user)
     ret_url = params[:next] || url_for_root(user)
     #password = params[:user][:password]
     #_jabber_auth(user.jabber, password) if user.jabber? && !user.jabber.nil?
     return ret_url
  end

#  rescue_from StandardError do |exception|
#    throw exception  if ENV['RAILS_ENV'] == 'void'
#    _error(exception)
#  end

  ##
  # pokud nemá člověk opravnění, 
  # * je to možná tím, že není přihlášeny,
  #   pak ho přihlaš, a po přihlášení sem přijď znova (param `next`).
  #   pokud dojde k chybě pošli email s informacemi
  # * pokud je přihlášený a nemá přistup, vyhoď chybu
  rescue_from CanCan::AccessDenied do |exception|
      if current_user.nil?
        redirect_to new_user_session_url(:next => request.path)
      else
        _error(exception)
      end
  end

  private
  def _error(exception)
    @errid = "ERR-#{rand(1000000)}"
    @error = "#{exception}"
    log "#{@errid}: #{@error}"

    Tep::Mailer.error(errid: @errid.to_s,
                      action: @_action_name.to_s,
                      error: @error.to_s,
                      timestamp: DateTime.now.strftime("%y-%m-%d %H:%M:%S"),
                      email: current_user.nil? ? nil : current_user.email,
                      params: params.to_hash,
                      host: request.remote_ip,
                      useragent: request.user_agent,
                      referer: request.referer,
                      backtrace: exception.backtrace.to_s,
                    ).deliver_later
    render :layout => nil, template: 'tep/error'
  end

  ##
  # obsolete, pokusy s jabberem
  def _jabber_auth(jabber, password)
   bosh_url = Rails.configuration.jabber_bosh_url
   rid, sid = SimpleBoshSession.get_session(bosh_url, jabber.jid, password)
   #log("rid=#{rid} sid=#{sid}")
   session[:jabber_rid] = rid
   session[:jabber_sid] = sid
  end


end
