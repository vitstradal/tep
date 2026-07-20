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
    # kid má ročník 7 a žádnou uloženou roli -> odhad účastník s otazníkem
    assert_match 'fa-user blue" title="účastník (odhad podle ročníku)"', response.body
    # data-hint pro stavový řádek v rohu
    assert_match 'data-hint="Jan Kid · Soustředění 2025 (2025-07-01) — účastník (odhad podle ročníku)"', response.body
    assert_match 'Jen dlouhodobé', response.body      # checkbox dle skupiny akce
  end

  test "history cell shows stored role without guess marker" do
    Act::EventParticipant.find_by(event_id: @old.id, participant_id: @kid.id).update!(role: 'org')
    sign_in @org
    get :history, params: { event_id: @event.id }
    assert_match 'fa-flag green" title="org"', response.body
  end

  test "history cell shows * when no role and no grade" do
    bezrocniku = Act::Participant.create!(name: 'Jan', last_name: 'Bezrocniku', nickname: '',
                                          email: 'bez@x.cz', user_id: make_user('bez@x.cz').id,
                                          activated: 'desact')
    enroll(@event, bezrocniku)
    enroll(@old, bezrocniku)
    sign_in @org
    get :history, params: { event_id: @event.id }
    assert_match '<strong title="byl na akci (role nezjištěna)">*</strong>', response.body
  end

  test "history sorts participants by grade then birth" do
    starsi  = make_participant('starsi@x.cz', make_user('starsi@x.cz').id)
    starsi.update!(grade: 9)
    mladsi  = make_participant('mladsi@x.cz', make_user('mladsi@x.cz').id)
    mladsi.update!(grade: 7, birth: Time.utc(2013, 1, 1))
    @kid.update!(grade: 7, birth: Time.utc(2012, 6, 1))   # stejný ročník, starší
    enroll(@event, starsi)
    enroll(@event, mladsi)

    sign_in @org
    get :history, params: { event_id: @event.id }
    body = response.body
    assert body.index('Kid') < body.index('Mladsi'),  'v ročníku řadí dle narození'
    assert body.index('Mladsi') < body.index('Starsi'), 'nižší ročník první'
    assert body.index('Vedouci') < body.index('Kid'),  'orgové zůstávají první'
  end

  test "soustredeni counts as long term even when weekend length" do
    Act::EventCategory.create!(code: 'so', name: 'Soustředění', visible: 'ev', multi_day: true)
    junior = Act::Event.create!(title: 'Sous junior', event_category: 'so',
                                event_start: Date.new(2025, 10, 3), event_end: Date.new(2025, 10, 5))
    assert junior.long_term?, 'soustředění (i víkendové) je dlouhodobé'
    enroll(junior, @kid)

    sign_in @org
    get :history, params: { event_id: @event.id }   # dlouhodobý tábor
    assert_match 'Sous junior', response.body        # v default filtru dlouhodobých
  end

  test "history with all=1 shows both groups, newest event first" do
    sign_in @org
    get :history, params: { event_id: @event.id, all: '1' }
    assert_response :success
    assert_match 'Soustředění 2025', response.body
    assert_match 'Vylet 2025', response.body
    assert_no_match(/Cizi akce/, response.body)
    # nejnovější akce vlevo (Soustředění 7/2025 před Výletem 5/2025)
    assert response.body.index('Soustředění 2025') < response.body.index('Vylet 2025')
  end

  test "history is not for plain users" do
    plain = make_user('plain@x.cz', [:user])
    sign_in plain
    get :history, params: { event_id: @event.id }
    assert_no_match(/Vylet 2025/, response.body)
  end
end
