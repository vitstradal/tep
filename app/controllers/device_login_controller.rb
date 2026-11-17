##
# Přihlášení pomocí jiného zařízení — strana nového zařízení
# (viz docs/superpowers/specs/2026-11-17-prihlaseni-v-mobilu-design.md).
class DeviceLoginController < ApplicationController
  authorize_resource class: false
  protect_from_forgery with: :exception

  COOKIE = Rails.env.production? ? '__Host-tep_dl' : 'tep_dl'

  before_action :_no_store, except: :novy

  # GET /prihlasit-zarizenim
  def novy
    session[:device_login_return_to] =
      safe_return_path(params[:next]) || safe_return_path(stored_location_for(:user))
  end

  # POST /prihlasit-zarizenim
  def vytvor
    old = _record
    token = SecureRandom.urlsafe_base64(32)
    record = DeviceLogin.create_for!(token: token, user_agent: request.user_agent, ip: request.remote_ip,
                                     return_to: session[:device_login_return_to] || old&.return_to)
    session.delete(:device_login_return_to)
    old&.cancel!
    cookies[COOKIE] = { value: token, httponly: true, same_site: :lax, secure: Rails.env.production?, path: '/' }
    render json: { icons: record.icons, expires_in: record.expires_in }
  rescue DeviceLogin::Busy
    render json: { error: 'Teď to nejde, zkus to za chvíli.' }, status: 429
  end

  # GET /prihlasit-zarizenim/stav
  def stav
    record = _record
    return render(json: { state: 'none' }) unless record

    case record.state
    when 'pending'
      left = record.expires_in
      render json: { state: left.positive? ? 'pending' : 'expired', expires_in: left }
    when 'approved'
      left = _approve_left(record)
      return render(json: { state: 'expired', expires_in: 0 }) unless left.positive?
      render json: { state: 'approved', expires_in: left, name: record.user.full_name.presence || record.user.email }
    else
      render json: { state: record.state, expires_in: 0 }
    end
  end

  # POST /prihlasit-zarizenim/ano
  def ano
    record = _record
    return render(json: { ok: false, error: 'Potvrzení vypršelo, začni znovu.' }) unless record && record.user

    user = record.user
    unless user.active_for_authentication?
      record.cancel!
      return render(json: { ok: false, error: I18n.t("devise.failure.#{user.inactive_message}") })
    end
    return render(json: { ok: false, error: 'Potvrzení vypršelo, začni znovu.' }) unless record.finish!(cookies[COOKIE])

    sign_out(:user) if warden.authenticated?(:user)
    sign_in(:user, user)
    Tep::Mailer.device_login_email(user, record.device_label, Time.current).deliver_later
    cookies.delete(COOKIE, path: '/')
    if record.return_to.present?
      add_success 'Jsi přihlášený, pokračuješ tam, kam jsi mířil.'
      url = record.return_to
    else
      add_success 'Jsi přihlášený.'
      url = url_for_root(user)
    end
    render json: { ok: true, url: url }
  end

  # POST /prihlasit-zarizenim/ne
  def ne
    _record&.cancel!(from: %w[approved])
    render json: { ok: true }
  end

  private

  def _record
    token = cookies[COOKIE]
    token.present? ? DeviceLogin.for_device(token) : nil
  end

  def _approve_left(record)
    [(record.approved_at + DeviceLogin::APPROVE_TTL - Time.current).ceil, 0].max
  end

  def _no_store
    response.headers['Cache-Control'] = 'no-store'
  end
end
