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

  test "show is public and carries endpoint urls for js" do
    get :show
    assert_response :success
    assert_select 'h2', 'Přihlásit pomocí jiného zařízení'
    assert_select '#device-login-new[data-create-url=?]', '/device_login'
    assert_select '#device-login-new[data-state-url=?]', '/device_login/state'
    assert_select '#device-login-new[data-yes-url=?]', '/device_login/accept'
    assert_select '#device-login-new[data-no-url=?]', '/device_login/decline'
    assert_select 'noscript'
  end

  test "show stores a local next as return target" do
    get :show, params: { next: '/sosna/reseni' }
    assert_equal '/sosna/reseni', session[:device_login_return_to]
  end

  test "show ignores a foreign next" do
    get :show, params: { next: '//evil.example/x' }
    assert_nil session[:device_login_return_to]
  end

  test "show falls back to devise stored location" do
    session['user_return_to'] = '/act/events'
    get :show
    assert_equal '/act/events', session[:device_login_return_to]
  end

  test "create creates a pending record bound to a fresh cookie" do
    session[:device_login_return_to] = '/kam'
    post :create
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

  test "create never reuses the cookie the browser sends" do
    cookies['tep_dl'] = 'attacker-chosen'
    post :create
    assert_response :success
    refute_equal 'attacker-chosen', cookies['tep_dl']
    assert_equal DeviceLogin.digest(cookies['tep_dl']), DeviceLogin.order(:id).last.device_digest
  end

  test "second create from the same browser cancels the old code and keeps the return target" do
    session[:device_login_return_to] = '/kam'
    post :create
    first_token = cookies['tep_dl']
    first = DeviceLogin.order(:id).last

    post :create
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

  test "busy second create leaves the previous code pending" do
    post :create
    first = DeviceLogin.order(:id).last
    DeviceLogin.stub(:create_for!, ->(**) { raise DeviceLogin::Busy }) do
      post :create
    end
    assert_response 429
    assert_equal 'pending', first.reload.state
    assert_equal 1, DeviceLogin.count
  end

  test "show ignores next with control characters" do
    get :show, params: { next: "/\t/evil.example" }
    assert_nil session[:device_login_return_to]
    post :create
    assert_nil DeviceLogin.order(:id).last.return_to
  end

  test "show keeps devise user_return_to in the session" do
    session['user_return_to'] = '/oauth/authorize?client_id=x'
    get :show
    assert_equal '/oauth/authorize?client_id=x', session['user_return_to']
    assert_equal '/oauth/authorize?client_id=x', session[:device_login_return_to]
  end

  test "create when busy answers 429 and creates nothing" do
    DeviceLogin.stub(:create_for!, ->(**) { raise DeviceLogin::Busy }) do
      post :create
    end
    assert_response 429
    assert_equal 'Teď to nejde, zkus to za chvíli.', json['error']
    assert_equal 0, DeviceLogin.count
  end

  test "state without cookie is none" do
    get :state
    assert_response :success
    assert_equal({ 'state' => 'none' }, json)
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test "state with unknown cookie is none" do
    pending
    cookies['tep_dl'] = 'someone-else'
    get :state
    assert_equal({ 'state' => 'none' }, json)
  end

  test "state pending reveals no name" do
    pending
    cookies['tep_dl'] = 'tok-new'
    get :state
    assert_response :success
    assert_equal 'pending', json['state']
    assert_equal 300, json['expires_in']
    refute json.key?('name')
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test "state approved reveals the full name" do
    u = user('jana@example.com')
    u.update_columns(name: 'Jana', last_name: 'Nováková')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    get :state
    assert_equal 'approved', json['state']
    assert_equal u.reload.full_name, json['name']
    assert_includes json['name'], 'Nováková'
    assert_equal 120, json['expires_in']
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test "state approved falls back to email when name is blank" do
    u = user('bezjmena@example.com')
    u.update_columns(name: '', last_name: '')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    get :state
    assert_equal 'bezjmena@example.com', json['name']
  end

  test "state of an outdated pending code is expired" do
    pending
    cookies['tep_dl'] = 'tok-new'
    travel 5.minutes + 1.second do
      get :state
    end
    assert_equal 'expired', json['state']
    assert_equal 0, json['expires_in']
  end

  test "state after the approve window is expired and hides the name" do
    approved(user('u@example.com'))
    cookies['tep_dl'] = 'tok-new'
    travel 2.minutes + 1.second do
      get :state
    end
    assert_equal 'expired', json['state']
    refute json.key?('name')
  end

  test "accept signs in the approving user without remember me and mails the owner" do
    u = user('u@example.com')
    rec = approved(u)
    cookies['tep_dl'] = 'tok-new'
    assert_enqueued_emails 1 do
      post :accept
    end
    assert_response :success
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
    assert_equal 'done', rec.reload.state
    assert_nil cookies[:remember_user_token]
    assert cookies['tep_dl'].blank?
    assert_equal ['Jsi přihlášený.'], flash[:success]
  end

  test "accept mail names the device and time" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    travel_to ActiveSupport::TimeZone['Europe/Prague'].local(2026, 11, 17, 9, 5) do
      perform_enqueued_jobs { post :accept }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal ['u@example.com'], mail.to
    assert_equal 'PIKOMAT: přihlášení na jiném zařízení', mail.subject
    assert_includes mail.body.encoded, 'iPhone · Safari'
    assert_includes mail.body.encoded, '17. 11. 9:05'
  end

  test "accept replaces a different signed in user with the approving one" do
    u = user('u@example.com')
    other = user('other@example.com')
    sign_in other
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
    assert_equal u, @controller.warden.user(:user)
  end

  test "accept with another browser cookie signs nobody in" do
    u = user('u@example.com')
    rec = approved(u)
    cookies['tep_dl'] = 'other-browser'
    assert_no_enqueued_emails { post :accept }
    assert_equal false, json['ok']
    assert json['error'].present?
    assert_nil @controller.current_user
    assert_equal 'approved', rec.reload.state
  end

  test "accept without cookie signs nobody in" do
    approved(user('u@example.com'))
    post :accept
    assert_equal false, json['ok']
    assert_nil @controller.current_user
  end

  test "accept on a still pending record signs nobody in" do
    rec = pending
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal false, json['ok']
    assert_nil @controller.current_user
    assert_equal 'pending', rec.reload.state
  end

  test "accept after the approve window signs nobody in" do
    u = user('u@example.com')
    rec = approved(u)
    cookies['tep_dl'] = 'tok-new'
    travel 2.minutes + 1.second do
      assert_no_enqueued_emails { post :accept }
    end
    assert_equal false, json['ok']
    assert_equal 'Potvrzení vypršelo, začni znovu.', json['error']
    assert_nil @controller.current_user
    assert_equal 'approved', rec.reload.state
  end

  test "accept just inside the approve window signs in" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    travel 2.minutes - 1.second do
      post :accept
    end
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
  end

  test "accept cannot be used twice" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal true, json['ok']
    sign_out :user
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal false, json['ok']
    assert_nil @controller.current_user
  end

  test "accept for a locked account cancels and signs nobody in" do
    u = user('locked@example.com')
    rec = approved(u)
    u.lock_access!(send_instructions: false)
    cookies['tep_dl'] = 'tok-new'
    assert_no_enqueued_emails { post :accept }
    assert_response :success
    assert_equal false, json['ok']
    assert_equal 'Váš účet je uzamčen.', json['error']
    assert_equal 'cancelled', rec.reload.state
    assert_nil @controller.current_user
  end

  test "accept for an unconfirmed account cancels and signs nobody in" do
    u = user('unconfirmed@example.com')
    rec = approved(u)
    u.update_columns(confirmed_at: nil, confirmation_sent_at: 1.year.ago)
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_response :success
    assert_equal false, json['ok']
    assert_equal I18n.t("devise.failure.#{u.reload.inactive_message}"), json['error']
    assert_includes json['error'], 'potvrdit'
    assert_equal 'cancelled', rec.reload.state
    assert_nil @controller.current_user
  end

  test "accept returns to the stored target" do
    u = user('u@example.com')
    approved(u, return_to: '/sosna/reseni')
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal true, json['ok']
    assert_equal '/sosna/reseni', json['url']
    assert_equal ['Jsi přihlášený, pokračuješ tam, kam jsi mířil.'], flash[:success]
  end

  test "accept without a stored target goes to the user's root" do
    u = user('u@example.com')
    approved(u)
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal true, json['ok']
    assert_equal @controller.url_for_root(u), json['url']
    assert_match %r{/sosna}, json['url']
  end

  test "decline cancels an approved record" do
    rec = approved(user('u@example.com'))
    cookies['tep_dl'] = 'tok-new'
    post :decline
    assert_response :success
    assert_equal true, json['ok']
    assert_equal 'cancelled', rec.reload.state
    assert_nil @controller.current_user
  end

  test "decline does not touch another browser's record" do
    rec = approved(user('u@example.com'))
    cookies['tep_dl'] = 'other-browser'
    post :decline
    assert_equal 'approved', rec.reload.state
  end

  test "full flow from show to signed in at next" do
    u = user('u@example.com')
    get :show, params: { next: '/act/events' }
    post :create
    token = cookies['tep_dl']
    rec = DeviceLogin.for_device(token)
    assert_equal '/act/events', rec.return_to
    assert rec.approve!(u)
    get :state
    assert_equal 'approved', json['state']
    post :accept
    assert_equal true, json['ok']
    assert_equal '/act/events', json['url']
    assert_equal u, @controller.current_user
    assert_equal 'done', rec.reload.state
  end

  test "create over https sets a secure __Host- cookie" do
    @request.env['HTTPS'] = 'on'
    post :create
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

  test "create over http sets a plain non-secure cookie" do
    post :create
    set_cookie = response.headers['Set-Cookie'].to_s
    assert_match(/(^|\n)tep_dl=/, set_cookie)
    refute_match(/__Host-/, set_cookie)
    refute_match(/;\s*secure/i, set_cookie)
  end

  test "over https only the __Host- cookie is read" do
    @request.env['HTTPS'] = 'on'
    pending
    cookies['tep_dl'] = 'tok-new'
    get :state
    assert_equal 'none', json['state']
    cookies['__Host-tep_dl'] = 'tok-new'
    get :state
    assert_equal 'pending', json['state']
  end

  test "accept over https signs in by the __Host- cookie and deletes it securely" do
    @request.env['HTTPS'] = 'on'
    u = user('u@example.com')
    rec = approved(u)
    cookies['__Host-tep_dl'] = 'tok-new'
    post :accept
    assert_equal true, json['ok']
    assert_equal u, @controller.current_user
    assert_equal 'done', rec.reload.state
    deletion = response.headers['Set-Cookie'].to_s.split("\n").find { |c| c.start_with?('__Host-tep_dl=') }
    assert deletion, 'expected __Host- cookie deletion'
    assert_match(/max-age=0|expires=Thu, 01 Jan 1970/i, deletion)
    assert_match(/;\s*secure/i, deletion)
    assert_match(/path=\//i, deletion)
  end

  test "show without next after an old targeted code gives a new code without target" do
    session[:device_login_return_to] = '/stary-cil'
    post :create
    assert_equal '/stary-cil', DeviceLogin.order(:id).last.return_to
    get :show
    assert session.key?(:device_login_return_to)
    post :create
    assert_response :success
    assert_nil DeviceLogin.order(:id).last.return_to
  end

  test "accept clears view_as and stored return targets" do
    u = user('u@example.com')
    approved(u, return_to: '/kam')
    session[:view_as] = 'user'
    session[:view_as_switch] = true
    session['user_return_to'] = '/jinam'
    session[:device_login_return_to] = '/jeste-jinam'
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal true, json['ok']
    assert_equal '/kam', json['url']
    assert_nil session[:view_as]
    assert_nil session[:view_as_switch]
    assert_nil session['user_return_to']
    assert_nil session[:device_login_return_to]
    assert_equal u, @controller.current_user
  end

  test "create without csrf token is rejected when forgery protection is on" do
    ActionController::Base.allow_forgery_protection = true
    assert_raises(ActionController::InvalidAuthenticityToken) { post :create }
    assert_equal 0, DeviceLogin.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "decline leaves a pending record pending" do
    rec = pending
    cookies['tep_dl'] = 'tok-new'
    post :decline
    assert_equal true, json['ok']
    assert_equal 'pending', rec.reload.state
  end

  def kod_ids
    Array(session[:device_login_kod_ids])
  end

  def code_of(rec)
    rec.code.split('-')
  end

  test "approve anonymously redirects to sign in" do
    get :approve
    assert_redirected_to new_user_session_path(next: '/device_login/approve')
  end

  test "approve shows 22 lettered icons, 4 slots and endpoint urls" do
    sign_in user('u@example.com')
    get :approve
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
    assert_select '#device-login-keyboard .device-login-clear[title=?]', 'Smazat poslední obrázek' do
      assert_select 'svg.device-login-backspace[aria-hidden=true]', 1
    end
    assert_select '#device-login-keyboard .device-login-clear', text: 'Smazat'
    assert_select '#device-login-keyboard[data-code-url=?]', '/device_login/approve/code'
    assert_select '#device-login-keyboard[data-confirm-url=?]', '/device_login/approve/confirm'
    assert_select '#device-login-keyboard[data-cancel-url=?]', '/device_login/approve/cancel'
    assert_select '#device-login-keyboard[data-state-url=?]', '/device_login/approve/state'
    assert_select '#device-login-keyboard .device-login-confirm.hide'
    assert_no_match(/Na novém zařízení dej/, response.body)
  end

  test "approve page has the keyboard on the left and the other-device instructions on the right" do
    sign_in user('u@example.com')
    get :approve
    url = 'http://test.host/device_login'
    assert_select '#device-login-keyboard .row > .col-sm-8' do
      assert_select '.device-login-heading', 'Zadej kód z druhého zařízení'
      assert_select '.device-login-grid .device-login-key', 22
      assert_select '.device-login-slot', 4
      assert_select '.device-login-clear'
      assert_select '.device-login-message'
      assert_select '.device-login-confirm'
      assert_select '.device-login-wait'
      assert_select '.device-login-home'
      assert_select '.device-login-again'
      assert_select '.device-login-qr', 0
    end
    assert_select '#device-login-keyboard .row > .col-sm-4' do
      assert_select 'a[href=?]', url, text: url
      assert_select '.device-login-qr[data-url=?]', url
      assert_select '.device-login-grid', 0
      assert_select 'p', /Na druhém zařízení otevři tuto adresu, nebo naskenuj QR kód/
      assert_select 'p', 'Ukážou se ti tam 4 obrázky – zadej je sem.'
    end
  end

  test "approve shows the absolute login page url as data-url, link text and loads qrcode.js" do
    sign_in user('u@example.com')
    get :approve
    assert_response :success
    url = 'http://test.host/device_login'
    assert_select '#device-login-keyboard [data-url]', 1
    assert_equal url, css_select('#device-login-keyboard .device-login-qr').first['data-url']
    assert_select '#device-login-keyboard .col-sm-4 a[href=?]', url, text: url
    assert_select 'script[src^=?]', '/javascripts/qrcode.js?v='
  end

  test "approve ends with a link back to the home page and a retry button" do
    sign_in user('u@example.com')
    get :approve
    assert_select '#device-login-keyboard a.device-login-home.hide[href=?]', '/', text: 'Zpět na hlavní stránku'
    assert_select '#device-login-keyboard button.device-login-again.hide', text: 'Zkusit znovu'
  end

  test "approve works for an org-only account" do
    sign_in user('o@example.com', roles: [:org])
    get :approve
    assert_response :success
    assert_select '#device-login-keyboard [data-i]', 22
  end

  test "approve works in view as anon" do
    sign_in user('m@example.com', roles: %i[org morg])
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    get :approve
    assert_response :success
    assert_select '#device-login-keyboard [data-i]', 22
  end

  test "enter_code from another network describes the device and leaves the record pending" do
    u = user('u@example.com')
    sign_in u
    freeze_time
    rec = pending
    @request.remote_addr = '192.168.5.5'
    travel 42.seconds
    post :enter_code, params: { code: code_of(rec) }
    assert_response :success
    assert_equal({ 'ok' => true, 'id' => rec.id, 'device' => 'iPhone · Safari', 'same_network' => false,
                   'age' => 42, 'approved' => false }, json)
    assert_equal 'pending', rec.reload.state
    assert_nil rec.user_id
    assert_equal [rec.id], kod_ids
    assert_equal [true], DeviceLoginAttempt.where(user_id: u.id).pluck(:ok)
  end

  test "enter_code from the same network approves at once as the real user" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :enter_code, params: { code: code_of(rec) }
    assert_response :success
    assert_equal({ 'ok' => true, 'id' => rec.id, 'device' => 'iPhone · Safari', 'same_network' => true,
                   'approved' => true }, json)
    rec.reload
    assert_equal 'approved', rec.state
    assert_equal u.id, rec.user_id
    assert rec.approved_at.present?
    assert_equal [rec.id], kod_ids
  end

  test "enter_code from the same network whose approval loses a race fails without binding the session" do
    sign_in user('u@example.com')
    rec = pending
    @request.remote_addr = '10.0.0.1'
    loser = DeviceLogin.find(rec.id)
    loser.stub(:approve!, false) do
      DeviceLogin.stub(:find_pending, loser) { post :enter_code, params: { code: code_of(rec) } }
    end
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
    assert_equal [], kod_ids
    assert_equal 'pending', rec.reload.state
  end

  test "enter_code from the same network in view as anon approves as the real user" do
    morg = user('m@example.com', roles: %i[org morg])
    sign_in morg
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :enter_code, params: { code: code_of(rec) }
    assert_equal true, json['approved']
    assert_equal 'approved', rec.reload.state
    assert_equal morg.id, rec.user_id
  end

  test "enter_code from the same ipv6 /64 approves at once" do
    u = user('u@example.com')
    sign_in u
    rec = DeviceLogin.create_for!(token: 'tok-new', user_agent: UA, ip: '2001:db8:1:2::10', return_to: nil)
    @request.remote_addr = '2001:db8:1:2:aaaa::1'
    post :enter_code, params: { code: code_of(rec) }
    assert_equal true, json['same_network']
    assert_equal true, json['approved']
    assert_equal 'approved', rec.reload.state
  end

  test "enter_code wrong code fails and counts as a failed attempt" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    wrong = rec.code.split('-').map(&:to_i).tap { |c| c[0] = (c[0] + 1) % DeviceLogin::ICONS.size }
    post :enter_code, params: { code: wrong }
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
    assert_equal [false], DeviceLoginAttempt.where(user_id: u.id).pluck(:ok)
  end

  test "enter_code rejects malformed codes without error" do
    sign_in user('u@example.com')
    [%w[1 2 3], %w[1 2 3 x], %w[1 2 3 22], %w[1 2 3 -1], '1-2-3-4'].each do |code|
      post :enter_code, params: { code: code }
      assert_response :success
      assert_equal false, json['ok'], code.inspect
    end
  end

  test "enter_code rejects index 22 even when a record has that code" do
    sign_in user('u@example.com')
    rec = pending
    rec.update_columns(code: '1-2-3-22')
    post :enter_code, params: { code: %w[1 2 3 22] }
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
    assert_equal [], kod_ids
  end

  test "enter_code sixth wrong code within a minute is throttled even when right" do
    sign_in user('u@example.com')
    rec = pending
    wrong = rec.code.split('-').map(&:to_i).tap { |c| c[0] = (c[0] + 1) % DeviceLogin::ICONS.size }
    5.times do
      post :enter_code, params: { code: wrong }
      assert_response :success
      assert_equal false, json['ok']
    end
    post :enter_code, params: { code: wrong }
    assert_response 429
    assert_equal({ 'ok' => false, 'error' => 'Moc pokusů, zkus to za chvíli.' }, json)
    post :enter_code, params: { code: code_of(rec) }
    assert_response 429
    assert_nil json['id']
  end

  test "enter_code of an expired code fails" do
    sign_in user('u@example.com')
    rec = pending
    travel_to(rec.expires_at + 1.second) do
      post :enter_code, params: { code: code_of(rec) }
    end
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
  end

  test "enter_code of a code cancelled by the new device fails" do
    sign_in user('u@example.com')
    rec = pending
    assert rec.cancel!
    post :enter_code, params: { code: code_of(rec) }
    assert_response :success
    assert_equal({ 'ok' => false, 'error' => 'Kód neplatí nebo vypršel.' }, json)
  end

  test "enter_code anonymously is 401" do
    rec = pending
    post :enter_code, params: { code: code_of(rec) }
    assert_response 401
    assert_equal({ 'ok' => false }, json)
    assert_equal 0, DeviceLoginAttempt.count
  end

  def entered(rec)
    post :enter_code, params: { code: code_of(rec) }
    assert_equal true, json['ok']
    assert_equal rec.id, json['id']
  end

  test "confirm approves the code entered via enter_code, only once" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    entered(rec)
    assert_equal [rec.id], kod_ids
    post :confirm, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    rec.reload
    assert_equal 'approved', rec.state
    assert_equal u.id, rec.user_id
    assert rec.approved_at.present?
    assert_equal [rec.id], kod_ids
    post :confirm, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal u.id, rec.reload.user_id
  end

  test "confirm of an id never returned by enter_code changes nothing" do
    sign_in user('u@example.com')
    foreign = pending('tok-foreign')
    post :confirm, params: { id: foreign.id }
    assert_equal({ 'ok' => false }, json)
    foreign.reload
    assert_equal 'pending', foreign.state
    assert_nil foreign.user_id
  end

  test "confirm after enter_code for one record cannot approve another" do
    sign_in user('u@example.com')
    a = pending('tok-a')
    b = pending('tok-b')
    entered(a)
    post :confirm, params: { id: b.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', b.reload.state
    assert_nil b.user_id
    assert_equal 'pending', a.reload.state
    assert_equal [a.id], kod_ids
    post :confirm, params: { id: a.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'approved', a.reload.state
  end

  test "confirm cannot take over a record approved by someone else" do
    other = user('other@example.com')
    rec = approved(other)
    sign_in user('u@example.com')
    session[:device_login_kod_ids] = [rec.id]
    post :confirm, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal other.id, rec.reload.user_id
  end

  test "confirm of a code that expired or was cancelled after enter_code fails" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    travel_to(rec.expires_at + 1.second) do
      post :confirm, params: { id: rec.id }
    end
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', rec.reload.state
    assert_nil rec.user_id
    rec2 = pending('tok-2')
    entered(rec2)
    assert rec2.cancel!
    post :confirm, params: { id: rec2.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'cancelled', rec2.reload.state
    assert_nil rec2.user_id
  end

  test "confirm in view as anon approves as the real user" do
    morg = user('m@example.com', roles: %i[org morg])
    sign_in morg
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    rec = pending
    entered(rec)
    post :confirm, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    rec.reload
    assert_equal 'approved', rec.state
    assert_equal morg.id, rec.user_id
  end

  test "confirm anonymously is 401 and changes nothing" do
    rec = pending
    session[:device_login_kod_ids] = [rec.id]
    post :confirm, params: { id: rec.id }
    assert_response 401
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', rec.reload.state
  end

  test "cancel cancels the code entered via enter_code" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    post :cancel, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', rec.reload.state
    assert_equal [], kod_ids
  end

  test "cancel of an id never returned by enter_code changes nothing" do
    sign_in user('u@example.com')
    foreign = pending('tok-foreign')
    post :cancel, params: { id: foreign.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', foreign.reload.state
  end

  test "cancel after enter_code for one record cannot cancel another" do
    sign_in user('u@example.com')
    a = pending('tok-a')
    b = pending('tok-b')
    entered(a)
    post :cancel, params: { id: b.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', b.reload.state
    assert_equal 'pending', a.reload.state
  end

  test "cancel leaves a record approved by someone else alone" do
    other = user('other@example.com')
    rec = approved(other)
    sign_in user('u@example.com')
    session[:device_login_kod_ids] = [rec.id]
    post :cancel, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'approved', rec.reload.state
    assert_equal other.id, rec.user_id
  end

  test "cancel after immediate same-network approval cancels it for the new device" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :enter_code, params: { code: code_of(rec) }
    assert_equal true, json['approved']
    post :cancel, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', rec.reload.state
    assert_equal [], kod_ids
    cookies['tep_dl'] = 'tok-new'
    get :state
    assert_equal 'cancelled', json['state']
    assert_no_enqueued_emails { post :accept }
    assert_equal false, json['ok']
    assert_equal 'cancelled', rec.reload.state
  end

  test "cancel after confirm cancels the approval" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    entered(rec)
    post :confirm, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    post :cancel, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', rec.reload.state
    assert_equal [], kod_ids
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal false, json['ok']
  end

  test "cancel of a finished login fails and keeps it done" do
    u = user('u@example.com')
    sign_in u
    rec = pending
    entered(rec)
    post :confirm, params: { id: rec.id }
    assert rec.reload.finish!('tok-new')
    post :cancel, params: { id: rec.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'done', rec.reload.state
  end

  test "cancel anonymously is 401 and changes nothing" do
    rec = pending
    session[:device_login_kod_ids] = [rec.id]
    post :cancel, params: { id: rec.id }
    assert_response 401
    assert_equal 'pending', rec.reload.state
  end

  test "enter_code without csrf token is rejected when forgery protection is on" do
    sign_in user('u@example.com')
    rec = pending
    ActionController::Base.allow_forgery_protection = true
    assert_raises(ActionController::InvalidAuthenticityToken) { post :enter_code, params: { code: code_of(rec) } }
    assert_equal 0, DeviceLoginAttempt.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "approve_state without a session key is none and uncached" do
    sign_in user('u@example.com')
    rec = pending
    get :approve_state, params: { id: rec.id }
    assert_response :success
    assert_equal({ 'state' => 'none' }, json)
    assert_equal 'no-store', response.headers['Cache-Control']
  end

  test "approve_state follows only the record of its own session key, never another user's" do
    a = user('a@example.com')
    rec_a = pending('tok-a')
    rec_b = pending('tok-b')
    assert rec_a.approve!(a)
    sign_in user('b@example.com')
    entered(rec_b)
    get :approve_state, params: { id: rec_b.id }
    assert_equal({ 'state' => 'pending' }, json)
    get :approve_state, params: { id: rec_a.id }
    assert_equal({ 'state' => 'none' }, json)
    assert rec_a.finish!('tok-a')
    get :approve_state, params: { id: rec_a.id }
    assert_equal({ 'state' => 'none' }, json)
    get :approve_state, params: { id: rec_b.id }
    assert_equal({ 'state' => 'pending' }, json)
    assert_equal [rec_b.id], kod_ids
    assert rec_b.cancel!
    get :approve_state, params: { id: rec_b.id }
    assert_equal({ 'state' => 'cancelled' }, json)
    assert_equal 'done', rec_a.reload.state
  end

  test "approve_state with a key of a deleted record is none and drops the key" do
    sign_in user('u@example.com')
    session[:device_login_kod_ids] = [999_999]
    get :approve_state, params: { id: 999_999 }
    assert_equal({ 'state' => 'none' }, json)
    assert_equal [], kod_ids
  end

  test "approve_state follows pending, approved and done and then forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    get :approve_state, params: { id: rec.id }
    assert_equal({ 'state' => 'pending' }, json)
    assert_equal 'no-store', response.headers['Cache-Control']
    post :confirm, params: { id: rec.id }
    get :approve_state, params: { id: rec.id }
    assert_equal({ 'state' => 'approved' }, json)
    assert_equal [rec.id], kod_ids
    cookies['tep_dl'] = 'tok-new'
    post :accept
    assert_equal true, json['ok']
    get :approve_state, params: { id: rec.id }
    assert_equal({ 'state' => 'done' }, json)
    assert_equal [], kod_ids
    get :approve_state, params: { id: rec.id }
    assert_equal({ 'state' => 'none' }, json)
  end

  test "approve_state is approved right after a same-network enter_code" do
    sign_in user('u@example.com')
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :enter_code, params: { code: code_of(rec) }
    get :approve_state, params: { id: rec.id }
    assert_equal({ 'state' => 'approved' }, json)
  end

  test "approve_state reports cancelled by the new device and forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    post :confirm, params: { id: rec.id }
    cookies['tep_dl'] = 'tok-new'
    post :decline
    get :approve_state, params: { id: rec.id }
    assert_equal({ 'state' => 'cancelled' }, json)
    assert_equal [], kod_ids
  end

  test "approve_state reports an expired pending code and forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    travel_to(rec.expires_at - 1.second) do
      get :approve_state, params: { id: rec.id }
      assert_equal({ 'state' => 'pending' }, json)
    end
    travel_to(rec.expires_at + 1.second) do
      get :approve_state, params: { id: rec.id }
      assert_equal({ 'state' => 'expired' }, json)
    end
    assert_equal [], kod_ids
    assert_equal 'pending', rec.reload.state
  end

  test "approve_state reports an approval past its time as expired and forgets the key" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    post :confirm, params: { id: rec.id }
    approved_at = rec.reload.approved_at
    travel_to(approved_at + DeviceLogin::APPROVE_TTL - 1.second) do
      get :approve_state, params: { id: rec.id }
      assert_equal({ 'state' => 'approved' }, json)
    end
    travel_to(approved_at + DeviceLogin::APPROVE_TTL + 1.second) do
      get :approve_state, params: { id: rec.id }
      assert_equal({ 'state' => 'expired' }, json)
    end
    assert_equal [], kod_ids
  end

  test "approve_state anonymously is 401" do
    rec = pending
    session[:device_login_kod_ids] = [rec.id]
    get :approve_state, params: { id: rec.id }
    assert_response 401
    assert_equal({ 'ok' => false }, json)
  end

  test "two tabs keep their own entered codes" do
    u = user('u@example.com')
    sign_in u
    a = pending('tok-a')
    b = pending('tok-b')
    @request.remote_addr = '10.0.0.1'
    post :enter_code, params: { code: code_of(a) }
    assert_equal true, json['approved']
    post :enter_code, params: { code: code_of(b) }
    assert_equal true, json['approved']
    assert_equal [a.id, b.id], kod_ids
    get :approve_state, params: { id: a.id }
    assert_equal({ 'state' => 'approved' }, json)
    post :cancel, params: { id: a.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', a.reload.state
    assert_equal 'approved', b.reload.state
    assert_equal u.id, b.user_id
    assert_equal [b.id], kod_ids
    get :approve_state, params: { id: a.id }
    assert_equal({ 'state' => 'none' }, json)
    get :approve_state, params: { id: b.id }
    assert_equal({ 'state' => 'approved' }, json)
  end

  test "entered codes keep only the newest five" do
    sign_in user('u@example.com')
    recs = Array.new(6) { |i| pending("tok-#{i}") }
    recs.each { |r| entered(r) }
    assert_equal recs.drop(1).map(&:id), kod_ids
    get :approve_state, params: { id: recs.first.id }
    assert_equal({ 'state' => 'none' }, json)
    post :cancel, params: { id: recs.first.id }
    assert_equal({ 'ok' => false }, json)
    assert_equal 'pending', recs.first.reload.state
  end

  test "entering the same code twice keeps one entry" do
    sign_in user('u@example.com')
    rec = pending
    entered(rec)
    entered(rec)
    assert_equal [rec.id], kod_ids
  end

  test "cancel in view as anon cancels a same-network approval of the real user" do
    morg = user('m@example.com', roles: %i[org morg])
    sign_in morg
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    rec = pending
    @request.remote_addr = '10.0.0.1'
    post :enter_code, params: { code: code_of(rec) }
    assert_equal true, json['approved']
    assert_equal morg.id, rec.reload.user_id
    post :cancel, params: { id: rec.id }
    assert_equal({ 'ok' => true }, json)
    assert_equal 'cancelled', rec.reload.state
    assert_equal [], kod_ids
  end
end
