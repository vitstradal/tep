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
    json['icons'].each { |icon| assert_includes DeviceLogin::ICONS, icon }
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
end
