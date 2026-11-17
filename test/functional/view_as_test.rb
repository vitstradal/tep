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

  test "morg sees switch only after enabling it in user menu, org never" do
    sign_in @morg
    get :show, params: { event_id: @event.id }
    assert_select 'select#view_as', 0
    assert_select 'form[action="/view_as/toggle"]'
    session[:view_as_switch] = true
    get :show, params: { event_id: @event.id }
    assert_select 'select#view_as'
    sign_out @morg
    sign_in @org
    get :show, params: { event_id: @event.id }
    assert_select 'select#view_as', 0
    assert_select 'form[action="/view_as/toggle"]', 0
  end

  test "user menu offers sign in on another device to everyone, view as toggle only to morg" do
    u = make_user('u@x.cz', [:user])
    sign_in u
    get :show, params: { event_id: @event.id }
    assert_select 'li.dropdown .dropdown-toggle .hidden-xs', 'u@x.cz'
    assert_select 'li.dropdown .dropdown-menu a[href="/prihlasit-zarizeni"]', /Přihlásit na jiném zařízení/
    assert_select 'li.dropdown .dropdown-menu a[href="/prihlasit-zarizeni"] i.fa-mobile'
    assert_select 'form[action="/view_as/toggle"]', 0
    sign_out u
    sign_in @org
    get :show, params: { event_id: @event.id }
    assert_select 'li.dropdown .dropdown-menu a[href="/prihlasit-zarizeni"]'
    assert_select 'form[action="/view_as/toggle"]', 0
    sign_out @org
    sign_in @morg
    session[:view_as_switch] = true
    session[:view_as] = 'user'
    get :show, params: { event_id: @event.id }
    assert_select 'li.dropdown .dropdown-toggle .hidden-xs', 'morg@x.cz'
    assert_select 'li.dropdown .dropdown-menu a[href="/prihlasit-zarizeni"]'
    assert_select 'li.dropdown .dropdown-menu form[action="/view_as/toggle"]'
  end

  test "view as without enabled switch is ignored" do
    sign_in @morg
    session[:view_as] = 'org'
    get :edit, params: { event_id: @event.id }
    assert_no_match '<fieldset disabled>', response.body
  end

  test "view as org drops morg rights without touching the db" do
    sign_in @morg
    get :edit, params: { event_id: @event.id }
    assert_no_match '<fieldset disabled>', response.body
    session[:view_as_switch] = true
    session[:view_as] = 'org'
    get :edit, params: { event_id: @event.id }
    assert_match '<fieldset disabled>', response.body
    assert_select 'select#view_as option[selected][value="org"]'
    assert @morg.reload.morg?
  end

  test "view as anon hides org tabs and keeps the switch" do
    sign_in @morg
    session[:view_as_switch] = true
    session[:view_as] = 'anon'
    get :show, params: { event_id: @event.id }
    assert_no_match 'Nastavení akce', response.body
    assert_select 'select#view_as option[selected][value="anon"]'
  end

  test "morg-only event stays hidden when viewing as org" do
    @event.update_columns(visible: 'morg')
    sign_in @morg
    session[:view_as_switch] = true
    session[:view_as] = 'org'
    get :show, params: { event_id: @event.id }
    assert_match 'Přístup zamítnut', response.body
  end

  test "org cannot elevate via session" do
    sign_in @org
    session[:view_as_switch] = true
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
    post :toggle
    assert_nil session[:view_as_switch]
    post :update, params: { view_as: 'anon' }
    assert_nil session[:view_as]
    sign_out org
    morg = User.new(email: 'm@x.cz', password: 'password123'); morg.skip_confirmation!; morg.save!
    morg.roles << :org; morg.roles << :morg; morg.save!
    sign_in morg
    post :update, params: { view_as: 'user' }
    assert_nil session[:view_as]
    post :toggle
    assert session[:view_as_switch]
    post :update, params: { view_as: 'user' }
    assert_equal 'user', session[:view_as]
    post :toggle
    assert_nil session[:view_as_switch]
    assert_nil session[:view_as]
    post :toggle
    post :update, params: { view_as: 'user' }
    post :update, params: { view_as: '' }
    assert_nil session[:view_as]
    post :update, params: { view_as: 'admin' }
    assert_nil session[:view_as]
  end
end

class ViewAsNoBreadcrumbTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "switch is shown also on pages without breadcrumb" do
    morg = User.new(email: 'morg2@x.cz', password: 'password123', roles: %i[org morg])
    morg.skip_confirmation!
    morg.save!
    sign_in morg
    post '/view_as/toggle'
    get '/users/edit'
    assert_response :success
    assert_select 'select#view_as'
  end
end

class MenuBreadcrumbTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "page without own breadcrumb gets section and item from the sidebar menu" do
    u = User.new(email: 'u@x.cz', password: 'password123', roles: %i[user])
    u.skip_confirmation!
    u.save!
    sign_in u
    get '/users/edit'
    assert_select '#breadcrumbs ul.breadcrumb > li', 2
    assert_select '#breadcrumbs ul.breadcrumb > li:first-child .dropdown-toggle', /Uživatel/
    assert_select '#breadcrumbs ul.breadcrumb > li:first-child .dropdown-menu a', /Moje řešení/
    assert_select '#breadcrumbs ul.breadcrumb > li:last-child a[href="/users/edit"]', 'Změna hesla'
  end

  test "detail pages extend the menu breadcrumb, aliases map to their menu item" do
    admin = User.new(email: 'adm@x.cz', password: 'password123', roles: %i[org admin user])
    admin.skip_confirmation!
    admin.save!
    sign_in admin
    get "/user/#{admin.id}/show"
    assert_select 'ul.breadcrumb > li', 3
    assert_select 'ul.breadcrumb > li:nth-child(2) a', 'Uživatelé'
    assert_select 'ul.breadcrumb > li:last-child a', 'adm@x.cz'
    sign_out admin
    get '/prihlaska'
    assert_select 'ul.breadcrumb > li:last-child a[href="/sosna/solver/new"]', 'Nový řešitel'
  end
end
