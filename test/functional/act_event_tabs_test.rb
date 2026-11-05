require 'test_helper'

class ActEventTabsTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventsController

  setup do
    @kid = User.new(email: 'kid@x.cz', password: 'password123', roles: [:user])
    @kid.skip_confirmation!
    @kid.save!
    @p = Act::Participant.create!(name: 'Jan', last_name: 'Kid', nickname: '', grade: 7, email: 'kid@x.cz',
                                  user_id: @kid.id, activated: 'full', phone: '1', parent_email: 'r@x.cz',
                                  parent_phone: '2', birth: Date.new(2014, 1, 1), address: 'A', birth_number: '1',
                                  health_insurance: '111', sex: 'male')
    @org = User.new(email: 'org@x.cz', password: 'password123')
    @org.skip_confirmation!
    @org.save!
    @org.roles << :org
    @org.save!
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    @event = Act::Event.create!(title: 'Tábor', event_category: 'tabor',
                                event_start: Date.current + 10, event_end: Date.current + 20)
  end

  def tab_hrefs
    css_select('ul#myTab a').map { |a| a['href'] }
  end

  test "enrollment tab holds the form, people and documents have own tabs" do
    @event.update_columns(paper_template: 'x')
    Act::EventParticipant.create!(event_id: @event.id, participant_id: @p.id, status: 'yes', chosen: 'participant')
    sign_in @kid
    get :show, params: { event_id: @event.id }
    assert_response :success
    assert_select 'form#new_event_participant, form[action$="/enroll"]'
    assert_no_match 'Přihlášení účastníci', response.body
    assert_includes tab_hrefs, "/act/events/#{@event.id}/people"
    assert_includes tab_hrefs, "/act/events/#{@event.id}/documents"

    @event.update_columns(spec_place: true, spec_mass: true)
    get :people, params: { event_id: @event.id }
    assert_match 'Přihlášení účastníci', response.body
    assert_no_match 'Nástup', response.body
    assert_no_match 'Mše', response.body
    assert_select 'li.active a[href=?]', "/act/events/#{@event.id}/people"

    get :documents, params: { event_id: @event.id }
    assert_select "a[href=?]", "/act/events/#{@event.id}/papers_please/my"
  end

  test "people and documents tabs hidden when empty for participant, people shown to org" do
    sign_in @kid
    get :show, params: { event_id: @event.id }
    assert_not_includes tab_hrefs, "/act/events/#{@event.id}/people"
    assert_not_includes tab_hrefs, "/act/events/#{@event.id}/documents"
    sign_out @kid
    sign_in @org
    get :show, params: { event_id: @event.id }
    assert_includes tab_hrefs, "/act/events/#{@event.id}/people"
    @event.update_columns(spec_place: true)
    get :people, params: { event_id: @event.id }
    assert_match 'Nástup', response.body
  end

  test "enrollment disappears for participants a week after the end" do
    @event.update_columns(event_start: Date.current - 20, event_end: Date.current - 8)
    sign_in @kid
    get :show, params: { event_id: @event.id }
    assert_redirected_to act_event_people_path(@event)
    get :people, params: { event_id: @event.id }
    assert_not_includes tab_hrefs, "/act/events/#{@event.id}"
    get :index
    assert_no_match(/přihlašování/, response.body)

    @event.update_columns(event_end: Date.current - 7)
    get :show, params: { event_id: @event.id }
    assert_response :success

    @event.update_columns(event_end: Date.current - 8)
    sign_out @kid
    sign_in @org
    get :show, params: { event_id: @event.id }
    assert_response :success
    get :index
    assert_match(/přihlašování/, response.body)
  end
end

class ActEventDocumentsTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventsController

  setup do
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    @event = Act::Event.create!(title: 'Tábor', event_category: 'tabor', paper_template: 'x.pdf',
                                event_start: Date.current + 10, event_end: Date.current + 20)
  end

  test "anonymous gets benefits and login/registration links" do
    get :documents, params: { event_id: @event.id }
    assert_match 'předvyplníme', response.body
    assert_select 'a[href^="/users/sign_in"]'
    assert_select 'a[href="/act/participants/new_complet"]'
    assert_select "a[href=?]", "/act/events/#{@event.id}/papers_please/my"
    assert_select 'table', 0
    get :my_papers_please, params: { event_id: @event.id }
    assert_response :success
  end

  test "participant sees filled values and edit link" do
    kid = User.new(email: 'kid@x.cz', password: 'password123', roles: [:user])
    kid.skip_confirmation!
    kid.save!
    p = Act::Participant.create!(name: 'Jan', last_name: 'Kid', nickname: '', grade: 7, email: 'kid@x.cz',
                                 user_id: kid.id, activated: 'full', phone: '777', parent_email: 'r@x.cz',
                                 parent_phone: '2', birth: Date.new(2014, 1, 1), address: 'Ulice 1, Praha', birth_number: '140101/1234',
                                 health_insurance: '111', sex: 'male')
    sign_in kid
    get :documents, params: { event_id: @event.id }
    assert_match '140101/1234', response.body
    assert_match '1. 1. 2014', response.body
    assert_match 'nevyplněno', response.body
    assert_no_match 'Zdravotník', response.body
    assert_select "a[href=?]", "/act/participants/#{p.id}/edit"
    assert_select "a[href=?]", "/act/events/#{@event.id}/papers_please/my"
  end

  test "paper keys strip suffixes" do
    assert_equal %i[name address rc], Act::Event.paper_keys(['name', 'name+1', 'adress+2', 'rc'])
  end
end
