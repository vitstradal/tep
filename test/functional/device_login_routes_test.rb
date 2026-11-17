require 'test_helper'

class DeviceLoginRoutesTest < ActionDispatch::IntegrationTest
  ROUTES = [
    [:get,  '/device_login',                 'show',          :device_login],
    [:post, '/device_login',                 'create',        :device_login_create],
    [:get,  '/device_login/state',           'state',         :device_login_state],
    [:post, '/device_login/accept',          'accept',        :device_login_accept],
    [:post, '/device_login/decline',         'decline',       :device_login_decline],
    [:get,  '/device_login/approve',         'approve',       :device_login_approve],
    [:post, '/device_login/approve/code',    'enter_code',    :device_login_approve_code],
    [:post, '/device_login/approve/confirm', 'confirm',       :device_login_approve_confirm],
    [:post, '/device_login/approve/cancel',  'cancel',        :device_login_approve_cancel],
    [:get,  '/device_login/approve/state',   'approve_state', :device_login_approve_state]
  ].freeze

  ROUTES.each do |verb, path, action, name|
    test "#{verb} #{path} routes to device_login##{action}" do
      assert_routing({ method: verb, path: path }, controller: 'device_login', action: action)
      assert_equal path, Rails.application.routes.url_helpers.public_send("#{name}_path")
    end
  end

  test "old czech paths no longer route to device_login" do
    %w[/prihlasit-zarizenim /prihlasit-zarizeni /prihlasit-zarizeni/kod].each do |path|
      assert_not_equal 'device_login', Rails.application.routes.recognize_path(path, method: :get)[:controller]
    end
  end
end
