require 'simple_bosh_session'

##
# Controller od kterého se odvozují ostatní kotrolery v tepu.
#
# Je jednak kvůli řešení errorů (generuje se error_id, a zasílá se mail).
#
# Druhý důvod je `after_sign_in_path_for` hook kam se přesměrovat po nalohování.
#
# === rescue_from `CanCan::AccessDenied`
#
# pokud nemá člověk opravnění, 
# * je to možná tím, že není přihlášeny,
#   pak ho přihlaš, a po přihlášení sem přijď znova (param `next`).
#   pokud dojde k chybě pošli email s informacemi
# * pokud je přihlášený a nemá přistup, vyhoď chybu, pošli email s chybou {error}[rdoc-ref:Tep::Mailer.error]

class ApplicationController < ActionController::Base
  protect_from_forgery

  include ApplicationHelper

  ##
  # po nalogování na lokální cestu z `next`, jinak na uloženou adresu, jinak na root
  def after_sign_in_path_for(user)
    safe_return_path(params[:next]) || safe_return_path(stored_location_for(user)) || url_for_root(user)
  end

#  rescue_from StandardError do |exception|
#    throw exception  if ENV['RAILS_ENV'] == 'void'
#    _error(exception)
#  end

  # náhled „jak to vidí“ pro morgy: role se jen ubírají, nikdy nepřidávají
  VIEW_AS_ROLES = { 'morg' => %i[org morg user], 'org' => %i[org user], 'user' => %i[user], 'anon' => nil }.freeze
  VIEW_AS_TXT = { 'morg' => 'morg', 'org' => 'org', 'user' => 'účastník', 'anon' => 'nepřihlášený' }.freeze

  helper_method :real_user, :view_as, :view_as_allowed?, :view_as_switch?

  def real_user
    warden.authenticate(scope: :user)
  end

  def view_as_allowed?(user = real_user)
    !!(user && (user.admin? || user.morg?))
  end

  def view_as_switch?
    !!session[:view_as_switch] && view_as_allowed?
  end

  def view_as
    level = session[:view_as]
    level if VIEW_AS_ROLES.key?(level) && view_as_switch?
  end

  def current_user
    real = super
    level = view_as
    return real if level.nil?
    return nil if level == 'anon'
    return @view_as_user if @view_as_user && @view_as_user.id == real.id
    @view_as_user = User.find(real.id).tap do |u|
      u.roles = u.roles.to_a & VIEW_AS_ROLES[level]
      u.readonly!
    end
  end

  rescue_from CanCan::AccessDenied do |exception|
      if current_user.nil? && view_as
        add_alert "Jako #{VIEW_AS_TXT[view_as]} sem nemáš přístup."
        redirect_to root_path
      elsif current_user.nil?
        redirect_to new_user_session_url(:next => request.path)
      else
        _error(exception)
      end
  end

  protected

  # jen lokální cesta (začíná `/`, ne `//` ani `/\`), jinak nil
  def safe_return_path(path)
    path if path.is_a?(String) && path.start_with?('/') && !path.start_with?('//', '/\\')
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
                      params: params.to_unsafe_h.to_s,
                      host: request.remote_ip,
                      useragent: request.user_agent,
                      referer: request.referer,
                      backtrace: exception.backtrace.to_s,
                    ).deliver_later
    render :layout => nil, template: 'tep/error'
  end

###  ##
###  # obsolete, pokusy s jabberem
###  def _jabber_auth(jabber, password)
###   bosh_url = Rails.configuration.jabber_bosh_url
###   rid, sid = SimpleBoshSession.get_session(bosh_url, jabber.jid, password)
###   #log("rid=#{rid} sid=#{sid}")
###   session[:jabber_rid] = rid
###   session[:jabber_sid] = sid
###  end

end
