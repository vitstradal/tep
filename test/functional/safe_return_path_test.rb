require 'test_helper'

class SafeReturnPathTest < ActionController::TestCase
  tests Devise::SessionsController
  include Devise::Test::ControllerHelpers

  setup do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    @user = User.new(email: 'return@example.com', password: 'password123', roles: [:user])
    @user.skip_confirmation!
    @user.save!
  end

  def login(extra = {})
    post :create, params: { user: { email: @user.email, password: 'password123' } }.merge(extra)
  end

  test 'next with local path redirects there' do
    login(next: '/sosna')
    assert_redirected_to '/sosna'
  end

  test 'next with external url is ignored' do
    login(next: 'https://evil.example/')
    refute_match(/evil/, response.location)
  end

  test 'protocol-relative next is ignored' do
    login(next: '//evil.example/x')
    refute_match(/evil/, response.location)
  end

  test 'backslash next is ignored' do
    login(next: '/\\evil.example')
    refute_match(/evil/, response.location)
  end

  {"tab" => "/\t/evil.example", "newline" => "/\n/evil.example", "carriage return" => "/\r/evil.example",
   "space" => "/ /evil.example", "nul" => "/\u0000/evil.example"}.each do |name, path|
    test "next with #{name} inside is ignored" do
      login(next: path)
      assert_redirected_to '/sosna/solutions/user'
    end
  end

  test 'stored location is used' do
    session['user_return_to'] = '/oauth/authorize?client_id=x'
    login
    assert_redirected_to '/oauth/authorize?client_id=x'
  end

  test 'login page links to device login keeping next' do
    get :new, params: { next: '/sosna' }
    assert_select 'a[href=?]', '/prihlasit-zarizenim?next=%2Fsosna', 'Přihlásit pomocí jiného zařízení'
  end
end
