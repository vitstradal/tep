# Přihlášení pomocí jiného zařízení, strana nového zařízení.
class DeviceLoginController < ApplicationController
  SIGNED_IN = %i[klavesnice kod potvrdit zrusit stav_moje].freeze

  authorize_resource class: false, except: SIGNED_IN
  protect_from_forgery with: :exception

  before_action :_no_store, except: %i[novy klavesnice]
  before_action :_require_real_user, only: SIGNED_IN

  def novy
    session[:device_login_return_to] =
      safe_return_path(params[:next]) || safe_return_path(session['user_return_to'])
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

  def klavesnice; end

  def kod
    attempt = DeviceLoginAttempt.begin!(real_user)
    return render(json: { ok: false, error: 'Moc pokusů, zkus to za chvíli.' }, status: 429) unless attempt

    record = DeviceLogin.find_pending(_code_param)
    return render(json: { ok: false, error: 'Kód neplatí nebo vypršel.' }) unless record

    attempt.succeed!
    same = record.same_network?(request.remote_ip)
    return render(json: { ok: false, error: 'Kód neplatí nebo vypršel.' }) if same && !record.approve!(real_user)

    session[:device_login_kod_id] = record.id
    reply = { ok: true, id: record.id, device: record.device_label, same_network: same, approved: same }
    reply[:age] = (Time.current - record.created_at).to_i unless same
    render json: reply
  end

  def potvrdit
    record = _entered_record
    render json: { ok: !!record&.approve!(real_user) }
  end

  def zrusit
    record = _entered_record
    ok = !!record && [nil, real_user.id].include?(record.user_id) && record.cancel!(from: %w[pending approved])
    session.delete(:device_login_kod_id) if ok
    render json: { ok: ok }
  end

  def stav_moje
    id = session[:device_login_kod_id]
    record = id && DeviceLogin.find_by(id: id)
    state = record ? _my_state(record) : 'none'
    session.delete(:device_login_kod_id) unless %w[pending approved].include?(state)
    render json: { state: state }
  end

  private

  def _require_real_user
    unless real_user
      return redirect_to(new_user_session_path(next: request.path)) if action_name == 'klavesnice'

      return render(json: { ok: false }, status: 401)
    end
    Ability.new(real_user).authorize!(action_name.to_sym, :device_login)
  end

  # jen záznam, jehož kód tahle session zadala přes `kod`
  def _entered_record
    id = session[:device_login_kod_id]
    return nil unless id && params[:id].to_s == id.to_s

    DeviceLogin.find_by(id: id)
  end

  def _my_state(record)
    case record.state
    when 'pending' then record.expires_in.positive? ? 'pending' : 'expired'
    when 'approved' then record.approve_expires_in.positive? ? 'approved' : 'expired'
    when 'done', 'cancelled' then record.state
    else 'expired'
    end
  end

  def _code_param
    code = params[:code]
    return nil unless code.is_a?(Array) && code.all? { |c| c.is_a?(String) && c.match?(/\A\d{1,2}\z/) }

    code.map(&:to_i)
  end

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
