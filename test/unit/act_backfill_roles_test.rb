require 'test_helper'
require 'rake'

class ActBackfillRolesTest < ActiveSupport::TestCase
  setup do
    Tep::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['act:backfill_roles'].reenable
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    # školní rok se počítá od 1. 9.; „letošní" akce dáme do aktuálního měsíce
    @new_event = Act::Event.create!(title: 'Letos', event_category: 'tabor',
                                    event_start: Date.today, event_end: Date.today + 10)
    @old_event = Act::Event.create!(title: 'Pravek', event_category: 'tabor',
                                    event_start: Date.new(2015, 8, 1), event_end: Date.new(2015, 8, 10))
  end

  def make_participant(email, roles: [], with_user: true)
    user = nil
    if with_user
      user = User.new(email: email, password: 'password123', roles: roles)
      user.skip_confirmation!
      user.save!
    end
    Act::Participant.create!(name: 'Jan', last_name: email.split('@').first, nickname: '',
                             grade: 7, email: email, user_id: user&.id, activated: 'desact')
  end

  def enroll(event, participant)
    Act::EventParticipant.create!(event_id: event.id, participant_id: participant.id,
                                  status: 'yes', chosen: 'participant')
  end

  test "backfill fills roles from account state only for current school year" do
    org_p  = make_participant('org@x.cz', roles: [:org])
    kid_p  = make_participant('kid@x.cz')
    solo_p = make_participant('solo@x.cz', with_user: false)

    ep_org  = enroll(@new_event, org_p)
    ep_kid  = enroll(@new_event, kid_p)
    ep_solo = enroll(@new_event, solo_p)
    ep_old  = enroll(@old_event, kid_p)

    capture_io { Rake::Task['act:backfill_roles'].invoke }

    assert_equal 'org',         ep_org.reload.role
    assert_equal 'participant', ep_kid.reload.role
    assert_nil ep_solo.reload.role, 'bez účtu se neukládá (odhad je jen zobrazovací)'
    assert_nil ep_old.reload.role,  'stará akce zůstává nezjištěná'
  end
end
