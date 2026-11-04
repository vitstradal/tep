require 'test_helper'

class ActEventsOrgAccessTest < ActionController::TestCase
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
    @event = Act::Event.create!(title: 'Tábor 2026', event_category: 'tabor',
                                event_start: Date.new(2026, 8, 1), event_end: Date.new(2026, 8, 14))
  end

  test "org sees event settings read-only and morg actions greyed out" do
    sign_in @org
    get :edit, params: { event_id: @event.id }
    assert_response :success
    assert_match '<fieldset disabled>', response.body
    assert_match 'Jen pro morga', response.body
    assert_no_match(%r{href="/act/events/\d+/enroll_others}, response.body)
  end

  test "org event page shows morg buttons disabled" do
    sign_in @org
    get :show, params: { event_id: @event.id }
    assert_response :success
    assert_match 'Nastavení akce', response.body
    assert_no_match(%r{href="/act/events/\d+/display_participants}, response.body)
    assert_match 'btn disabled', response.body
  end

  test "morg can list and enroll participants" do
    sign_in @morg
    get :edit, params: { event_id: @event.id }
    assert_no_match(/<fieldset disabled>/, response.body)
    get :display_participants, params: { event_id: @event.id }
    assert_response :success
    get :enroll_others, params: { event_id: @event.id }
    assert_response :success
    get :edit_participants, params: { event_id: @event.id }
    assert_response :success
  end

  test "org can read the events manual" do
    sign_in @org
    get :jakna
    assert_response :success
  end

  test "event in preparation is visible only to morg" do
    @event.update!(visible: 'morg')
    sign_in @org
    get :show, params: { event_id: @event.id }
    assert_match 'akce se teprve připravuje', response.body
    get :index
    assert_no_match 'Tábor 2026', response.body
    sign_out @org
    sign_in @morg
    get :index
    assert_match 'Tábor 2026', response.body
    get :show, params: { event_id: @event.id }
    assert_no_match 'akce se teprve připravuje', response.body
  end
end
