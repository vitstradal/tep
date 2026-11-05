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

  test "t-shirt size offered on enrollment and shown to morg" do
    @event.update!(spec_tshirt: true, spec_tshirt_detail: '128, S,M')
    sign_in @morg
    get :edit, params: { event_id: @event.id }
    assert_match 'Na akci se rozdávají trička', response.body
    get :edit_participants, params: { event_id: @event.id }
    assert_match '<th>Tričko</th>', response.body
    get :display_participants, params: { event_id: @event.id }
    assert_match 'Velikost trička', response.body
  end

  test "t-shirt size is preselected from participant and remembered on change" do
    @event.update!(spec_tshirt: true, spec_tshirt_detail: '128, S,M',
                   event_start: Date.today + 30, event_end: Date.today + 40)
    kid = make_user('kid@x.cz', [:user])
    p = Act::Participant.create!(name: 'Jan', last_name: 'Kid', nickname: '', grade: 7, email: 'kid@x.cz',
                                 user_id: kid.id, activated: 'full', tshirt: 'S', phone: '1', parent_email: 'r@x.cz',
                                 parent_phone: '2', birth: Date.new(2014, 1, 1), address: 'A', birth_number: '1',
                                 health_insurance: '111', sex: 'male')
    sign_in kid
    get :show, params: { event_id: @event.id }
    assert_select 'select#event_participant_tshirt option', 3
    assert_select 'select#event_participant_tshirt option[selected][value="S"]'
    post :enroll, params: { event_id: @event.id,
                            event_participant: { event_id: @event.id, participant_id: p.id, status: 'yes', chosen: 'participant', tshirt: 'M' } }
    assert_equal 'M', Act::EventParticipant.find_by(event_id: @event.id, participant_id: p.id).tshirt
    assert_equal 'M', p.reload.tshirt
    sign_out kid
    sign_in @morg
    get :display_participants, params: { event_id: @event.id, fmt: 'csv', col: '1' * 30 }
    assert_match(/Velikost trička/, response.body)
    assert_match(/,M\s*\z/, response.body)
  end
end
