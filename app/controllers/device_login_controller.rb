# Přihlášení pomocí jiného zařízení, strana nového zařízení.
class DeviceLoginController < ApplicationController
  authorize_resource class: false
  protect_from_forgery with: :exception

  before_action :_no_store, except: :novy

  def novy
    session[:device_login_return_to] =
      safe_return_path(params[:next]) || safe_return_path(stored_location_for(:user))
  end

  def vytvor
    old = _record
    return_to = session.key?(:device_login_return_to) ? session[:device_login_return_to] : old&.return_to
    token = SecureRandom.urlsafe_base64(32)
    record = DeviceLogin.create_for!(token: token, user_agent: request.user_agent, ip: request.remote_ip,
                                     return_to: return_to)
    session.delete(:device_login_return_to)
    old&.cancel!
    cookies[_cookie_name] = { value: token, httponly: true, same_site: :lax, secure: request.ssl?, path: '/' }
    render json: { icons: record.icons, expires_in: record.expires_in }
  rescue DeviceLogin::Busy
    render json: { error: 'Teď to nejde, zkus to za chvíli.' }, status: 429
  end

  def stav
    record = _record
    return render(json: { state: 'none' }) unless record

    case record.state
    when 'pending'
      left = record.expires_in
      render json: { state: left.positive? ? 'pending' : 'expired', expires_in: left }
    when 'approved'
      left = record.approve_expires_in
      return render(json: { state: 'expired', expires_in: 0 }) unless left.positive?
      render json: { state: 'approved', expires_in: left, name: record.user.full_name.presence || record.user.email }
    else
      render json: { state: record.state, expires_in: 0 }
    end
  end

  def ano
    record = _record
    return render(json: { ok: false, error: 'Potvrzení vypršelo, začni znovu.' }) unless record && record.user

    user = record.user
    unless user.active_for_authentication?
      record.cancel!
      return render(json: { ok: false, error: I18n.t("devise.failure.#{user.inactive_message}") })
    end
    return render(json: { ok: false, error: 'Potvrzení vypršelo, začni znovu.' }) unless record.finish!(cookies[_cookie_name])

    sign_out(:user) if warden.authenticated?(:user)
    sign_in(:user, user)
    %i[view_as view_as_switch device_login_return_to].each { |key| session.delete(key) }
    session.delete('user_return_to')
    Tep::Mailer.device_login_email(user, record.device_label, Time.current).deliver_later
    cookies.delete(_cookie_name, path: '/', secure: request.ssl?)
    if record.return_to.present?
      add_success 'Jsi přihlášený, pokračuješ tam, kam jsi mířil.'
      url = record.return_to
    else
      add_success 'Jsi přihlášený.'
      url = url_for_root(user)
    end
    render json: { ok: true, url: url }
  end

  def ne
    _record&.cancel!(from: %w[approved])
    render json: { ok: true }
  end

  private

  def _cookie_name
    request.ssl? ? '__Host-tep_dl' : 'tep_dl'
  end

  def _record
    token = cookies[_cookie_name]
    token.present? ? DeviceLogin.for_device(token) : nil
  end

  def _no_store
    response.headers['Cache-Control'] = 'no-store'
  end
end
