require 'test_helper'

class ViewAsTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventsController

  def make_user(email, roles)
    u = User.new(email: email, password: 'password123')
    u.skip_confirmation!
    u.save!
    roles.each { |r| u.roles << r }
    u.save!
    u
  end

  setup do
    @org  = make_user('org@x.cz', [:org])
    @morg = make_user('morg@x.cz', [:org, :morg])
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    @event = Act::Event.create!(title: 'Tábor', event_category: 'tabor',
                                event_start: Date.current + 10, event_end: Date.current + 20)
  end

  test "morg sees switch, org does not" do
    sign_in @morg
    get :show, params: { event_id: @event.id }
    assert_select 'select#view_as'
    sign_out @morg
    sign_in @org
    get :show, params: { event_id: @event.id }
    assert_select 'select#view_as', 0
  end

  test "view as org drops morg rights without touching the db" do
    sign_in @morg
    get :edit, params: { event_id: @event.id }
    assert_no_match '<fieldset disabled>', response.body
    session[:view_as] = 'org'
    get :edit, params: { event_id: @event.id }
    assert_match '<fieldset disabled>', response.body
    assert_select 'select#view_as option[selected][value="org"]'
    assert @morg.reload.morg?
  end

  test "view as anon hides org tabs and keeps the switch" do
    sign_in @morg
    session[:view_as] = 'anon'
    get :show, params: { event_id: @event.id }
    assert_no_match 'Nastavení akce', response.body
    assert_select 'select#view_as option[selected][value="anon"]'
  end

  test "morg-only event stays hidden when viewing as org" do
    @event.update_columns(visible: 'morg')
    sign_in @morg
    session[:view_as] = 'org'
    get :show, params: { event_id: @event.id }
    assert_match 'Přístup zamítnut', response.body
  end

  test "org cannot elevate via session" do
    sign_in @org
    session[:view_as] = 'morg'
    get :edit, params: { event_id: @event.id }
    assert_match '<fieldset disabled>', response.body
  end
end

class ViewAsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests ViewAsController

  test "only morg can switch" do
    org = User.new(email: 'o@x.cz', password: 'password123'); org.skip_confirmation!; org.save!; org.roles << :org; org.save!
    sign_in org
    post :update, params: { view_as: 'anon' }
    assert_nil session[:view_as]
    sign_out org
    morg = User.new(email: 'm@x.cz', password: 'password123'); morg.skip_confirmation!; morg.save!
    morg.roles << :org; morg.roles << :morg; morg.save!
    sign_in morg
    post :update, params: { view_as: 'user' }
    assert_equal 'user', session[:view_as]
    post :update, params: { view_as: '' }
    assert_nil session[:view_as]
    post :update, params: { view_as: 'admin' }
    assert_nil session[:view_as]
  end
end
