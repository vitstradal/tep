require 'test_helper'

class ActDisplayParticipantsTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventsController

  setup do
    morg = User.new(email: 'morg@x.cz', password: 'password123', roles: [:org, :morg])
    morg.skip_confirmation!
    morg.save!
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    @event = Act::Event.create!(title: 'Tábor', event_category: 'tabor',
                                event_start: Date.new(2026, 8, 1), event_end: Date.new(2026, 8, 14))
    [['Eva', 'Šimková', 'female', 6], ['Jan', 'Čermák', 'male', 8], ['Petr', 'Cibulka', 'male', 5],
     ['Org', 'Orgovský', 'male', 13]].each_with_index do |(name, last, sex, grade), i|
      user = nil
      if grade > 9
        user = User.new(email: "p#{i}@x.cz", password: 'password123', roles: [:org])
        user.skip_confirmation!
        user.save!
      end
      p = Act::Participant.create!(name: name, last_name: last, nickname: '', grade: grade, sex: sex,
                                   email: "p#{i}@x.cz", activated: 'desact', user_id: user&.id)
      Act::EventParticipant.create!(event_id: @event.id, participant_id: p.id, status: 'yes', chosen: 'participant')
    end
    sign_in morg
  end

  def csv(**params)
    get :display_participants, params: { event_id: @event.id, fmt: 'csv', **params }
    CSV.parse(response.body)
  end

  test "default shows surname and name of participants sorted by surname" do
    get :display_participants, params: { event_id: @event.id }
    assert_response :success
    assert_select 'button.toggle-vis.btn-primary', 2
    assert_select 'button.toggle-group.btn-primary[data-group="org"]', 0
    rows = csv
    assert_equal %w[Příjmení Jméno], rows.first
    assert_equal %w[Cibulka Čermák Šimková], rows.drop(1).map(&:first)
  end

  test "sorting by sex puts men first, then by surname; by grade" do
    assert_equal %w[Cibulka Čermák Šimková], csv(sort: 'sex').drop(1).map(&:first)
    assert_equal %w[Cibulka Šimková Čermák], csv(sort: 'grade').drop(1).map(&:first)
  end

  test "sex as symbol, empty columns and orgs on request" do
    rows = csv(col: '111', empty: '2', org: '1')
    assert_equal ['Pohlaví', 'Příjmení', 'Jméno', '', ''], rows.first
    assert_includes rows, ['♂', 'Orgovský', 'Org', '', '']
    assert_includes rows, ['♀', 'Šimková', 'Eva', '', '']
    get :display_participants, params: { event_id: @event.id, fmt: 'pdf', col: '111', empty: '1' }
    assert_equal 'application/pdf', response.media_type
  end
end
