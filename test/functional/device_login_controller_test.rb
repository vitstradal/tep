require 'test_helper'
require 'minitest/mock'

class DeviceLoginControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1'.freeze

  def json
    JSON.parse(response.body)
  end

  def user(email, roles: [:user])
    User.new(email: email, password: 'password123', roles: roles).tap { |u| u.skip_confirmation!; u.save! }
  end

  def pending(token = 'tok-new', return_to: nil)
    DeviceLogin.create_for!(token: token, user_agent: UA, ip: '10.0.0.1', return_to: return_to)
  end

  def approved(u, token = 'tok-new', return_to: nil)
    pending(token, return_to: return_to).tap { |r| assert r.approve!(u) }
  end

  setup do
    @request.user_agent = UA
  end

  test "novy is public and carries endpoint urls for js" do
    get :novy
    assert_response :success
    assert_select 'h2', 'Přihlásit pomocí jiného zařízení'
    assert_select '#device-login-new[data-create-url=?]', '/prihlasit-zarizenim'
    assert_select '#device-login-new[data-state-url=?]', '/prihlasit-zarizenim/stav'
    assert_select '#device-login-new[data-yes-url=?]', '/prihlasit-zarizenim/ano'
    assert_select '#device-login-new[data-no-url=?]', '/prihlasit-zarizenim/ne'
    assert_select 'noscript'
  end

  test "novy stores a local next as return target" do
    get :novy, params: { next: '/sosna/reseni' }
    assert_equal '/sosna/reseni', session[:device_login_return_to]
  end

  test "novy ignores a foreign next" do
    get :novy, params: { next: '//evil.example/x' }
    assert_nil session[:device_login_return_to]
  end

  test "novy falls back to devise stored location" do
    session['user_return_to'] = '/act/events'
    get :novy
    assert_equal '/act/events', session[:device_login_return_to]
  end

  test "vytvor creates a pending record bound to a fresh cookie" do
    session[:device_login_return_to] = '/kam'
    post :vytvor
    assert_response :success
    token = cookies['tep_dl']
    assert token.present?
    assert_operator token.length, :>=, 40
    assert_equal 4, json['icons'].size
    json['icons'].each do |icon|
      assert_equal 3, icon.size
      assert_includes DeviceLogin::ICONS, icon
    end
    assert_equal 300, json['expires_in']
    rec = DeviceLogin.order(:id).last
    assert_equal 'pending', rec.state
    assert_equal DeviceLogin.digest(token), rec.device_digest
    assert_equal rec.icons, json['icons']
    assert_equal '/kam', rec.return_to
    assert_equal UA, rec.user_agent
    assert_nil session[:device_login_return_to]
    assert_includes response.headers['Set-Cookie'].to_s.downcase, 'httponly'
    assert_includes response.headers['Set-Cookie'].to_s.downcase, 'samesite=lax'
  end

  test "vytvor never reuses the cookie the browser sends" do
    cookies['tep_dl'] = 'attacker-chosen'
    post :vytvor
    assert_response :success
    refute_equal 'attacker-chosen', cookies['tep_dl']
    assert_equal DeviceLogin.digest(cookies['tep_dl']), DeviceLogin.order(:id).last.device_digest
  end

  test "second vytvor from the same browser cancels the old code and keeps the return target" do
    session[:device_login_return_to] = '/kam'
    post :vytvor
    first_token = cookies['tep_dl']
    first = DeviceLogin.order(:id).last

    post :vytvor
    assert_response :success
    second_token = cookies['tep_dl']
    refute_equal first_token, second_token
    second = DeviceLogin.order(:id).last
    refute_equal first.id, second.id
    assert_equal 'cancelled', first.reload.state
    assert_equal 'pending', second.state
    assert_equal DeviceLogin.digest(second_token), second.device_digest
    assert_equal '/kam', second.return_to
  end

  test "busy second vytvor leaves the previous code pending" do
    post :vytvor
    first = DeviceLogin.order(:id).last
    DeviceLogin.stub(:create_for!, ->(**) { raise DeviceLogin::Busy }) do
      post :vytvor
    end
    assert_response 429
    assert_equal 'pending', first.reload.state
    assert_equal 1, DeviceLogin.count
  end

  test "novy ignores next with control characters" do
    get :novy, params: { next: "/\t/evil.example" }
    assert_nil session[:device_login_return_to]
    post :vytvor
    assert_nil DeviceLogin.order(:id).last.return_to
  end

  test "novy keeps devise user_return_to in the session" do
    session['user_return_to'] = '/oauth/authorize?client_id=x'
    get :novy
    assert_equal '/oauth/authorize?client_id=x', session['user_return_to']
    assert_equal '/oauth/authorize?client_id=x', session[:device_login_return_to]
  end

  test "vytvor when busy answers 429 and creates nothing" do
    DeviceLogin.stub(:create_for!, ->(**) { raise DeviceLogin::Busy }) do
      post :vytvor
    end
    assert_response 429
    assert_equal 'Teď to nejde, zkus to za chvíli.', json['error']
    assert_equal 0, DeviceLogin.count
  end

  test "stav without cookie is none" do
    get :stav
    assert_response :success
    assert_equal({ 'state' => 'none' }, json)
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test "stav with unknown cookie is none" do
    pending
    cookies['tep_dl'] = 'someone-else'
    get :stav
    assert_equal({ 'state' => 'none' }, json)
  end

  test "stav pending reveals no name" do
    pending
    cookies['tep_dl'] = 'tok-new'
    get :stav
    assert_response :success
    assert_equal 'pending', json['state']
    assert_equal 300, json['expires_in']
    refute json.key?('name')
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test "stav approved reveals the full name" do
    u = user('jana@example.com')
    u.update_columns(name: 'Jana', last_name: 'Nováková')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    get :stav
    assert_equal 'approved', json['state']
    assert_equal u.reload.full_name, json['name']
    assert_includes json['name'], 'Nováková'
    assert_equal 120, json['expires_in']
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test "stav approved falls back to email when name is blank" do
    u = user('bezjmena@example.com')
    u.update_columns(name: '', last_name: '')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    get :stav
    assert_equal 'bezjmena@example.com', json['name']
  end

  test "stav of an outdated pending code is expired" do
    pending
    cookies['tep_dl'] = 'tok-new'
    travel 5.minutes + 1.second do
      get :stav
    end
    assert_equal 'expired', json['state']
    assert_equal 0, json['expires_in']
  end

  test "stav after the approve window is expired and hides the name" do
    approved(user('u@example.com'))
    cookies['tep_dl'] = 'tok-new'
    travel 2.minutes + 1.second do
      get :stav
    end
    assert_equal 'expired', json['state']
    refute json.key?('name')
  end

  test "ano signs in the approving user without remember me and mails the owner" do
    u = user('u@example.com')
    rec = approved(u)
    cookies['tep_dl'] = 'tok-new'
    assert_enqueued_emails 1 do
      post :ano
    end
    assert_response :success
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
    assert_equal 'done', rec.reload.state
    assert_nil cookies[:remember_user_token]
    assert cookies['tep_dl'].blank?
    assert_equal ['Jsi přihlášený.'], flash[:success]
  end

  test "ano mail names the device and time" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    travel_to ActiveSupport::TimeZone['Europe/Prague'].local(2026, 11, 17, 9, 5) do
      perform_enqueued_jobs { post :ano }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal ['u@example.com'], mail.to
    assert_equal 'PIKOMAT: přihlášení na jiném zařízení', mail.subject
    assert_includes mail.body.encoded, 'iPhone · Safari'
    assert_includes mail.body.encoded, '17. 11. 9:05'
  end

  test "ano replaces a different signed in user with the approving one" do
    u = user('u@example.com')
    other = user('other@example.com')
    sign_in other
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
    assert_equal u, @controller.warden.user(:user)
  end

  test "ano with another browser cookie signs nobody in" do
    u = user('u@example.com')
    rec = approved(u)
    cookies['tep_dl'] = 'other-browser'
    assert_no_enqueued_emails { post :ano }
    assert_equal false, json['ok']
    assert json['error'].present?
    assert_nil @controller.current_user
    assert_equal 'approved', rec.reload.state
  end

  test "ano without cookie signs nobody in" do
    approved(user('u@example.com'))
    post :ano
    assert_equal false, json['ok']
    assert_nil @controller.current_user
  end

  test "ano on a still pending record signs nobody in" do
    rec = pending
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal false, json['ok']
    assert_nil @controller.current_user
    assert_equal 'pending', rec.reload.state
  end

  test "ano after the approve window signs nobody in" do
    u = user('u@example.com')
    rec = approved(u)
    cookies['tep_dl'] = 'tok-new'
    travel 2.minutes + 1.second do
      assert_no_enqueued_emails { post :ano }
    end
    assert_equal false, json['ok']
    assert_equal 'Potvrzení vypršelo, začni znovu.', json['error']
    assert_nil @controller.current_user
    assert_equal 'approved', rec.reload.state
  end

  test "ano just inside the approve window signs in" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    travel 2.minutes - 1.second do
      post :ano
    end
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
  end

  test "ano cannot be used twice" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal true, json['ok']
    sign_out :user
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal false, json['ok']
    assert_nil @controller.current_user
  end

  test "ano for a locked account cancels and signs nobody in" do
    u = user('locked@example.com')
    rec = approved(u)
    u.lock_access!(send_instructions: false)
    cookies['tep_dl'] = 'tok-new'
    assert_no_enqueued_emails { post :ano }
    assert_response :success
    assert_equal false, json['ok']
    assert_equal 'Váš účet je uzamčen.', json['error']
    assert_equal 'cancelled', rec.reload.state
    assert_nil @controller.current_user
  end

  test "ano for an unconfirmed account cancels and signs nobody in" do
    u = user('unconfirmed@example.com')
    rec = approved(u)
    u.update_columns(confirmed_at: nil, confirmation_sent_at: 1.year.ago)
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_response :success
    assert_equal false, json['ok']
    assert_equal I18n.t("devise.failure.#{u.reload.inactive_message}"), json['error']
    assert_includes json['error'], 'potvrdit'
    assert_equal 'cancelled', rec.reload.state
    assert_nil @controller.current_user
  end

  test "ano returns to the stored target" do
    u = user('u@example.com')
    approved(u, return_to: '/sosna/reseni')
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal true, json['ok']
    assert_equal '/sosna/reseni', json['url']
    assert_equal ['Jsi přihlášený, pokračuješ tam, kam jsi mířil.'], flash[:success]
  end

  test "ano without a stored target goes to the user's root" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal true, json['ok']
    assert_equal @controller.url_for_root(u), json['url']
    assert_match %r{/sosna}, json['url']
  end

  test "ne cancels an approved record" do
    rec = approved(user('u@example.com'))
    cookies['tep_dl'] = 'tok-new'
    post :ne
    assert_response :success
    assert_equal true, json['ok']
    assert_equal 'cancelled', rec.reload.state
    assert_nil @controller.current_user
  end

  test "ne does not touch another browser's record" do
    rec = approved(user('u@example.com'))
    cookies['tep_dl'] = 'other-browser'
    post :ne
    assert_equal 'approved', rec.reload.state
  end

  test "full flow from novy to signed in at next" do
    u = user('u@example.com')
    get :novy, params: { next: '/act/events' }
    post :vytvor
    token = cookies['tep_dl']
    rec = DeviceLogin.for_device(token)
    assert_equal '/act/events', rec.return_to
    assert rec.approve!(u)
    get :stav
    assert_equal 'approved', json['state']
    post :ano
    assert_equal true, json['ok']
    assert_equal '/act/events', json['url']
    assert_equal u, @controller.current_user
    assert_equal 'done', rec.reload.state
  end

  test "vytvor over https sets a secure __Host- cookie" do
    @request.env['HTTPS'] = 'on'
    post :vytvor
    assert_response :success
    set_cookie = response.headers['Set-Cookie'].to_s
    assert_match(/__Host-tep_dl=/, set_cookie)
    assert_match(/;\s*secure/i, set_cookie)
    assert_match(/;\s*httponly/i, set_cookie)
    assert_match(/path=\//i, set_cookie)
    refute_match(/(^|\n)tep_dl=/, set_cookie)
    token = cookies['__Host-tep_dl']
    assert_equal DeviceLogin.digest(token), DeviceLogin.order(:id).last.device_digest
  end

  test "vytvor over http sets a plain non-secure cookie" do
    post :vytvor
    set_cookie = response.headers['Set-Cookie'].to_s
    assert_match(/(^|\n)tep_dl=/, set_cookie)
    refute_match(/__Host-/, set_cookie)
    refute_match(/;\s*secure/i, set_cookie)
  end

  test "over https only the __Host- cookie is read" do
    @request.env['HTTPS'] = 'on'
    pending
    cookies['tep_dl'] = 'tok-new'
    get :stav
    assert_equal 'none', json['state']
    cookies['__Host-tep_dl'] = 'tok-new'
    get :stav
    assert_equal 'pending', json['state']
  end

  test "ano over https signs in by the __Host- cookie and deletes it securely" do
    @request.env['HTTPS'] = 'on'
    u = user('u@example.com')
    rec = approved(u)
    cookies['__Host-tep_dl'] = 'tok-new'
    post :ano
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
    assert_equal 'done', rec.reload.state
    deletion = response.headers['Set-Cookie'].to_s.split("\n").find { |c| c.start_with?('__Host-tep_dl=') }
    assert deletion, 'expected __Host- cookie deletion'
    assert_match(/max-age=0|expires=Thu, 01 Jan 1970/i, deletion)
    assert_match(/;\s*secure/i, deletion)
    assert_match(/path=\//i, deletion)
  end

  test "novy without next after an old targeted code gives a new code without target" do
    session[:device_login_return_to] = '/stary-cil'
    post :vytvor
    assert_equal '/stary-cil', DeviceLogin.order(:id).last.return_to
    get :novy
    assert session.key?(:device_login_return_to)
    post :vytvor
    assert_response :success
    assert_nil DeviceLogin.order(:id).last.return_to
  end

  test "ano clears view_as and stored return targets" do
    u = user('u@example.com')
    approved(u, return_to: '/kam')
    session[:view_as] = 'user'
    session[:view_as_switch] = true
    session['user_return_to'] = '/jinam'
    session[:device_login_return_to] = '/jeste-jinam'
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal true, json['ok']
    assert_equal '/kam', json['url']
    assert_nil session[:view_as]
    assert_nil session[:view_as_switch]
    assert_nil session['user_return_to']
    assert_nil session[:device_login_return_to]
    assert_equal u, @controller.current_user
  end

  test "vytvor without csrf token is rejected when forgery protection is on" do
    ActionController::Base.allow_forgery_protection = true
    assert_raises(ActionController::InvalidAuthenticityToken) { post :vytvor }
    assert_equal 0, DeviceLogin.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "ne leaves a pending record pending" do
    rec = pending
    cookies['tep_dl'] = 'tok-new'
    post :ne
    assert_equal true, json['ok']
    assert_equal 'pending', rec.reload.state
  end

  def code_of(rec)
    rec.code.split('-')
  end

  test "klavesnice anonymously redirects to sign in" do
    get :klavesnice
    assert_redirected_to new_user_session_path(next: '/prihlasit-zarizeni')
  end

  test "klavesnice shows 22 lettered icons, 4 slots and endpoint urls" do
    sign_in user('u@example.com')
    get :klavesnice
    assert_response :success
    assert_select '#device-login-keyboard [data-i]', 22
    assert_select '#device-login-keyboard [data-letter]', 22
    assert_equal (0..21).map(&:to_s), css_select('#device-login-keyboard .device-login-key').map { |b| b['data-i'] }
    assert_equal DeviceLogin::ICONS.map(&:first),
                 css_select('#device-login-keyboard .device-login-key').map { |b| b['data-letter'] }
    DeviceLogin::ICONS.each_with_index do |(letter, emoji, name), i|
      assert_select "#device-login-keyboard [data-i='#{i}'][data-letter='#{letter}']" do
        assert_select '.device-login-letter', letter
        assert_select '.device-login-emoji', emoji
        assert_select '.device-login-name', name
      end
    end
    assert_select '#device-login-keyboard .device-login-slot', 4
    assert_select '#device-login-keyboard .device-login-clear', 'Smazat'
    assert_select '#device-login-keyboard[data-code-url=?]', '/prihlasit-zarizeni/kod'
    assert_select '#device-login-keyboard[data-confirm-url=?]', '/prihlasit-zarizeni/potvrdit'
    assert_select '#device-login-keyboard[data-cancel-url=?]', '/prihlasit-zarizeni/zrusit'
    assert_select '#device-login-keyboard[data-state-url=?]', '/prihlasit-zarizeni/stav'
    assert_select '#device-login-keyboard .device-login-confirm.hide'
    assert_match 'Na novém zařízení dej na přihlašovací stránce „Přihlásit pomocí jiného zařízení“ a sem zadej 4 obrázky, které se ti tam ukážou.', response.body
  end

  test "klavesnice works for an org-only account" do
    sign_in user('o@example.com', roles: [:org])
    get :klavesnice
    assert_response :success
    assert_select '#device-login-keyboard [data-i]', 22
  end

  test "klavesnice works in view as anon" do
    sign_in user('m@example.com', roles: %i[org morg])
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    get :klavesnice
    assert_response :success
    assert_select '#device-login-keyboard [data-i]', 22
  end

  test "kod from another network describes the device and leaves the record pending" do
    u = user('u@example.com')
    sign_in u
    freeze_time
    rec = pending
    @request.remote_addr = '192.168.5.5'
    travel 42.seconds
    post :kod, params: { code: code_of(rec) }
    assert_response :success
    assert_equal({ 'ok' => true, 'id' => rec.id, 'device' => 'iPhone · Safari', 'same_network' => false,
                   'age' => 42, 'approved' => false }, json)
    assert_equal 'pending', rec.reload.state
    assert_nil rec.user_id
    assert_equal rec.id, session[:device_login_kod_id]
    assert_equal [true], DeviceLoginAttempt.where(user_id: u.id).pluck(:ok)
  end

  test "kod from the same network approves at once as the real user" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :kod, params: { code: code_of(rec) }
    assert_response :success
    assert_equal({ 'ok' => true, 'id' => rec.id, 'device' => 'iPhone · Safari', 'same_network' => true,
                   'approved' => true }, json)
    rec.reload
    assert_equal 'approved', rec.state
    assert_equal u.id, rec.user_id
    assert rec.approved_at.present?
    assert_equal rec.id, session[:device_login_kod_id]
  end

  test "kod from the same network whose approval loses a race fails without binding the session" do
    sign_in user('u@example.com')
    rec = pending
    @request.remote_addr = '10.0.0.1'
    loser = DeviceLogin.find(rec.id)
    loser.stub(:approve!, false) do
      DeviceLogin.stub(:find_pending, loser) { post :kod, params: { code: code_of(rec) } }
    end
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
    assert_nil session[:device_login_kod_id]
    assert_equal 'pending', rec.reload.state
  end

  test "kod from the same network in view as anon approves as the real user" do
    morg = user('m@example.com', roles: %i[org morg])
    sign_in morg
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :kod, params: { code: code_of(rec) }
    assert_equal true, json['approved']
    assert_equal 'approved', rec.reload.state
    assert_equal morg.id, rec.user_id
  end

  test "kod from the same ipv6 /64 approves at once" do
    u = user('u@example.com')
    sign_in u
    rec = DeviceLogin.create_for!(token: 'tok-new', user_agent: UA, ip: '2001:db8:1:2::10', return_to: nil)
    @request.remote_addr = '2001:db8:1:2:aaaa::1'
    post :kod, params: { code: code_of(rec) }
    assert_equal true, json['same_network']
    assert_equal true, json['approved']
    assert_equal 'approved', rec.reload.state
  end

  test "kod wrong code fails and counts as a failed attempt" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    wrong = rec.code.split('-').map(&:to_i).tap { |c| c[0] = (c[0] + 1) % DeviceLogin::ICONS.size }
    post :kod, params: { code: wrong }
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
    assert_equal [false], DeviceLoginAttempt.where(user_id: u.id).pluck(:ok)
  end

  test "kod rejects malformed codes without error" do
    sign_in user('u@example.com')
    [%w[1 2 3], %w[1 2 3 x], %w[1 2 3 22], %w[1 2 3 -1], '1-2-3-4'].each do |code|
      post :kod, params: { code: code }
      assert_response :success
      assert_equal false, json['ok'], code.inspect
    end
  end

  test "kod rejects index 22 even when a record has that code" do
    sign_in user('u@example.com')
    rec = pending
    rec.update_columns(code: '1-2-3-22')
    post :kod, params: { code: %w[1 2 3 22] }
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
    assert_nil session[:device_login_kod_id]
  end

  test "kod sixth wrong code within a minute is throttled even when right" do
    sign_in user('u@example.com')
    rec = pending
    wrong = rec.code.split('-').map(&:to_i).tap { |c| c[0] = (c[0] + 1) % DeviceLogin::ICONS.size }
    5.times do
      post :kod, params: { code: wrong }
      assert_response :success
      assert_equal false, json['ok']
    end
    post :kod, params: { code: wrong }
    assert_response 429
    assert_equal({ 'ok' => false, 'error' => 'Moc pokusů, zkus to za chvíli.' }, json)
    post :kod, params: { code: code_of(rec) }
    assert_response 429
    assert_nil json['id']
  end

  test "kod of an expired code fails" do
    sign_in user('u@example.com')
    rec = pending
    travel_to(rec.expires_at + 1.second) do
      post :kod, params: { code: code_of(rec) }
    end
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
  end

  test "kod of a code cancelled by the new device fails" do
    sign_in user('u@example.com')
    rec = pending
    assert rec.cancel!
    post :kod, params: { code: code_of(rec) }
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
  end

  test "kod anonymously is 401" do
    rec = pending
    post :kod, params: { code: code_of(rec) }
    assert_response 401
    assert_equal({ 'ok' => false }, json)
    assert_equal 0, DeviceLoginAttempt.count
  end

  def entered(rec)
    post :kod, params: { code: code_of(rec) }
    assert_equal true, json['ok']
    assert_equal rec.id, json['id']
  end

  test "potvrdit approves the code entered via kod, only once" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    entered(rec)
    assert_equal rec.id, session[:device_login_kod_id]
    post :potvrdit, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    rec.reload
    assert_equal 'approved', rec.state
    assert_equal u.id, rec.user_id
    assert rec.approved_at.present?
    assert_equal rec.id, session[:device_login_kod_id]
    post :potvrdit, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal u.id, rec.reload.user_id
  end

  test "potvrdit of an id never returned by kod changes nothing" do
    sign_in user('u@example.com')
    foreign = pending('tok-foreign')
    post :potvrdit, params: { id: foreign.id }
    assert_equal({ 'ok' => false }, json)
    foreign.reload
    assert_equal 'pending', foreign.state
    assert_nil foreign.user_id
  end

  test "potvrdit after kod for one record cannot approve another" do
    sign_in user('u@example.com')
    a = pending('tok-a')
    b = pending('tok-b')
    entered(a)
    post :potvrdit, params: { id: b.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', b.reload.state
    assert_nil b.user_id
    assert_equal 'pending', a.reload.state
    assert_equal a.id, session[:device_login_kod_id]
    post :potvrdit, params: { id: a.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'approved', a.reload.state
  end

  test "potvrdit cannot take over a record approved by someone else" do
    other = user('other@example.com')
    rec = approved(other)
    sign_in user('u@example.com')
    session[:device_login_kod_id] = rec.id
    post :potvrdit, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal other.id, rec.reload.user_id
  end

  test "potvrdit of a code that expired or was cancelled after kod fails" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    travel_to(rec.expires_at + 1.second) do
      post :potvrdit, params: { id: rec.id }
    end
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', rec.reload.state
    assert_nil rec.user_id
    rec2 = pending('tok-2')
    entered(rec2)
    assert rec2.cancel!
    post :potvrdit, params: { id: rec2.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'cancelled', rec2.reload.state
    assert_nil rec2.user_id
  end

  test "potvrdit in view as anon approves as the real user" do
    morg = user('m@example.com', roles: %i[org morg])
    sign_in morg
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    rec = pending
    entered(rec)
    post :potvrdit, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    rec.reload
    assert_equal 'approved', rec.state
    assert_equal morg.id, rec.user_id
  end

  test "potvrdit anonymously is 401 and changes nothing" do
    rec = pending
    session[:device_login_kod_id] = rec.id
    post :potvrdit, params: { id: rec.id }
    assert_response 401
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', rec.reload.state
  end

  test "zrusit cancels the code entered via kod" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    post :zrusit, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', rec.reload.state
    assert_nil session[:device_login_kod_id]
  end

  test "zrusit of an id never returned by kod changes nothing" do
    sign_in user('u@example.com')
    foreign = pending('tok-foreign')
    post :zrusit, params: { id: foreign.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', foreign.reload.state
  end

  test "zrusit after kod for one record cannot cancel another" do
    sign_in user('u@example.com')
    a = pending('tok-a')
    b = pending('tok-b')
    entered(a)
    post :zrusit, params: { id: b.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', b.reload.state
    assert_equal 'pending', a.reload.state
  end

  test "zrusit leaves a record approved by someone else alone" do
    other = user('other@example.com')
    rec = approved(other)
    sign_in user('u@example.com')
    session[:device_login_kod_id] = rec.id
    post :zrusit, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'approved', rec.reload.state
    assert_equal other.id, rec.user_id
  end

  test "zrusit after immediate same-network approval cancels it for the new device" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :kod, params: { code: code_of(rec) }
    assert_equal true, json['approved']
    post :zrusit, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', rec.reload.state
    assert_nil session[:device_login_kod_id]
    cookies['tep_dl'] = 'tok-new'
    get :stav
    assert_equal 'cancelled', json['state']
    assert_no_enqueued_emails { post :ano }
    assert_equal false, json['ok']
    assert_equal 'cancelled', rec.reload.state
  end

  test "zrusit after potvrdit cancels the approval" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    entered(rec)
    post :potvrdit, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    post :zrusit, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', rec.reload.state
    assert_nil session[:device_login_kod_id]
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal false, json['ok']
  end

  test "zrusit of a finished login fails and keeps it done" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    entered(rec)
    post :potvrdit, params: { id: rec.id }
    assert rec.reload.finish!('tok-new')
    post :zrusit, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'done', rec.reload.state
  end

  test "zrusit anonymously is 401 and changes nothing" do
    rec = pending
    session[:device_login_kod_id] = rec.id
    post :zrusit, params: { id: rec.id }
    assert_response 401
    assert_equal 'pending', rec.reload.state
  end

  test "kod without csrf token is rejected when forgery protection is on" do
    sign_in user('u@example.com')
    rec = pending
    ActionController::Base.allow_forgery_protection = true
    assert_raises(ActionController::InvalidAuthenticityToken) { post :kod, params: { code: code_of(rec) } }
    assert_equal 0, DeviceLoginAttempt.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "stav_moje without a session key is none and uncached" do
    sign_in user('u@example.com')
    pending
    get :stav_moje
    assert_response :success
    assert_equal({ 'state' => 'none' }, json)
    assert_equal 'no-store', response.headers['Cache-Control']
  end

  test "stav_moje follows only the record of its own session key, never another user's" do
    a = user('a@example.com')
    rec_a = pending('tok-a')
    rec_b = pending('tok-b')
    assert rec_a.approve!(a)
    sign_in user('b@example.com')
    entered(rec_b)
    get :stav_moje
    assert_equal({ 'state' => 'pending' }, json)
    assert rec_a.finish!('tok-a')
    get :stav_moje
    assert_equal({ 'state' => 'pending' }, json)
    assert_equal rec_b.id, session[:device_login_kod_id]
    assert rec_b.cancel!
    get :stav_moje
    assert_equal({ 'state' => 'cancelled' }, json)
    assert_equal 'done', rec_a.reload.state
  end

  test "stav_moje with a key of a deleted record is none and drops the key" do
    sign_in user('u@example.com')
    session[:device_login_kod_id] = 999_999
    get :stav_moje
    assert_equal({ 'state' => 'none' }, json)
    assert_nil session[:device_login_kod_id]
  end

  test "stav_moje follows pending, approved and done and then forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    get :stav_moje
    assert_equal({ 'state' => 'pending' }, json)
    assert_equal 'no-store', response.headers['Cache-Control']
    post :potvrdit, params: { id: rec.id }
    get :stav_moje
    assert_equal({ 'state' => 'approved' }, json)
    assert_equal rec.id, session[:device_login_kod_id]
    cookies['tep_dl'] = 'tok-new'
    post :ano
    assert_equal true, json['ok']
    get :stav_moje
    assert_equal({ 'state' => 'done' }, json)
    assert_nil session[:device_login_kod_id]
    get :stav_moje
    assert_equal({ 'state' => 'none' }, json)
  end

  test "stav_moje is approved right after a same-network kod" do
    sign_in user('u@example.com')
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :kod, params: { code: code_of(rec) }
    get :stav_moje
    assert_equal({ 'state' => 'approved' }, json)
  end

  test "stav_moje reports cancelled by the new device and forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    post :potvrdit, params: { id: rec.id }
    cookies['tep_dl'] = 'tok-new'
    post :ne
    get :stav_moje
    assert_equal({ 'state' => 'cancelled' }, json)
    assert_nil session[:device_login_kod_id]
  end

  test "stav_moje reports an expired pending code and forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    travel_to(rec.expires_at - 1.second) do
      get :stav_moje
      assert_equal({ 'state' => 'pending' }, json)
    end
    travel_to(rec.expires_at + 1.second) do
      get :stav_moje
      assert_equal({ 'state' => 'expired' }, json)
    end
    assert_nil session[:device_login_kod_id]
    assert_equal 'pending', rec.reload.state
  end

  test "stav_moje reports an approval past its time as expired and forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    post :potvrdit, params: { id: rec.id }
    approved_at = rec.reload.approved_at
    travel_to(approved_at + DeviceLogin::APPROVE_TTL - 1.second) do
      get :stav_moje
      assert_equal({ 'state' => 'approved' }, json)
    end
    travel_to(approved_at + DeviceLogin::APPROVE_TTL + 1.second) do
      get :stav_moje
      assert_equal({ 'state' => 'expired' }, json)
    end
    assert_nil session[:device_login_kod_id]
  end

  test "stav_moje anonymously is 401" do
    rec = pending
    session[:device_login_kod_id] = rec.id
    get :stav_moje
    assert_response 401
    assert_equal({ 'ok' => false }, json)
  end
end
