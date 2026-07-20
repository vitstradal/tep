require 'test_helper'

class ActEventsHistoryTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventsController

  def make_user(email, roles = [])
    u = User.new(email: email, password: 'password123')
    u.skip_confirmation!
    u.save!
    roles.each { |r| u.roles << r }
    u.save!
    u
  end

  def make_participant(email, user_id)
    Act::Participant.create!(name: 'Jan', last_name: email.split('@').first.capitalize,
                             nickname: '', grade: 7, email: email, user_id: user_id,
                             activated: 'desact')
  end

  def enroll(event, participant)
    Act::EventParticipant.create!(event_id: event.id, participant_id: participant.id,
                                  status: 'yes', chosen: 'participant')
  end

  setup do
    @org = make_user('org@x.cz', [:org])
    @cat = Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    @event  = Act::Event.create!(title: 'Tábor 2026', event_category: 'tabor',      # dlouhodobá (14 dní)
                                 event_start: Date.new(2026, 8, 1), event_end: Date.new(2026, 8, 14))
    @old    = Act::Event.create!(title: 'Soustředění 2025', event_category: 'tabor', # dlouhodobá (7 dní)
                                 event_start: Date.new(2025, 7, 1), event_end: Date.new(2025, 7, 7))
    @short  = Act::Event.create!(title: 'Vylet 2025', event_category: 'tabor',       # krátkodobá (3 dny)
                                 event_start: Date.new(2025, 5, 1), event_end: Date.new(2025, 5, 3))
    @other  = Act::Event.create!(title: 'Cizi akce', event_category: 'tabor',
                                 event_start: Date.new(2025, 6, 1), event_end: Date.new(2025, 6, 12))

    @kid = make_participant('kid@x.cz', make_user('kid@x.cz').id)
    @ved = make_participant('vedouci@x.cz', @org.id)   # org účet -> vedoucí
    enroll(@event, @kid)
    enroll(@event, @ved)
    enroll(@old, @kid)      # kid byl na staré dlouhodobé akci
    enroll(@short, @kid)    # ...a na krátkodobé
    # na @other nebyl nikdo z účastníků @event
    @outsider = make_participant('jiny@x.cz', make_user('jiny@x.cz').id)
    enroll(@other, @outsider)
  end

  test "history shows people and same-group events by default" do
    sign_in @org
    get :history, params: { event_id: @event.id }
    assert_response :success
    assert_match 'Kid', response.body
    assert_match 'Vedouci', response.body
    assert_match 'Soustředění 2025', response.body    # stejná skupina (dlouhodobá)
    assert_no_match(/Vylet 2025/, response.body)      # krátkodobá — defaultně skryta
    assert_no_match(/Cizi akce/, response.body)       # akce bez průniku účastníků
    assert_match 'fa-user', response.body             # účastnická ikonka
    assert_match 'Jen dlouhodobé', response.body      # checkbox dle skupiny akce
  end

  test "history with all=1 shows both groups" do
    sign_in @org
    get :history, params: { event_id: @event.id, all: '1' }
    assert_response :success
    assert_match 'Soustředění 2025', response.body
    assert_match 'Vylet 2025', response.body
    assert_no_match(/Cizi akce/, response.body)
  end

  test "history is not for plain users" do
    plain = make_user('plain@x.cz', [:user])
    sign_in plain
    get :history, params: { event_id: @event.id }
    assert_no_match(/Vylet 2025/, response.body)
  end
end
