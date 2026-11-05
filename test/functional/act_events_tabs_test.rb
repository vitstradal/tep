require 'test_helper'

class ActEventsTabsTest < ActionController::TestCase
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
  end

  test "anonymous sees title without org tabs" do
    get :index
    assert_response :success
    assert_select 'h1', 'Akce Pikomatu'
    assert_select 'a[href="/act/event/jakna"]', 0
    assert_select 'a[href="/act/event_categories"]', 0
  end

  test "org sees tabs, new event greyed out" do
    sign_in @org
    get :index
    assert_select 'li.active a[href="/act/events"]', /Zobrazování akcí/
    assert_select 'a[href="/act/event/jakna"]'
    assert_select 'a[href="/act/event_categories"]'
    assert_select 'a[href="/act/events/new"]', 0
    assert_select 'li.disabled', /Nová akce/
  end

  test "morg tabs on new and jakna pages, no back button" do
    sign_in @morg
    get :new
    assert_select 'h1', 'Akce Pikomatu'
    assert_select 'li.active a[href="/act/events/new"]'
    assert_no_match 'Zpět', response.body
    get :jakna
    assert_select 'li.active a[href="/act/event/jakna"]'
    assert_no_match 'Zpět', response.body
  end
end

class ActEventCategoriesTabsTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventCategoriesController

  test "categories index has events tabs" do
    u = User.new(email: 'org@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    u.roles << :org
    u.save!
    sign_in u
    get :index
    assert_select 'h1', 'Akce Pikomatu'
    assert_select 'li.active a[href="/act/event_categories"]', /Typy akcí/
  end
end
