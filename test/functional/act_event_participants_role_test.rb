require 'test_helper'

class ActEventParticipantsRoleTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::EventParticipantsController

  setup do
    @morg = User.new(email: 'morg@x.cz', password: 'password123', roles: [:org, :morg])
    @morg.skip_confirmation!
    @morg.save!
    Act::EventCategory.create!(code: 'tabor', name: 'Tábor', visible: 'ev')
    @event = Act::Event.create!(title: 'Tábor 2026', event_category: 'tabor',
                                event_start: Date.new(2026, 8, 1), event_end: Date.new(2026, 8, 14))
    kid_user = User.new(email: 'kid@x.cz', password: 'password123')
    kid_user.skip_confirmation!
    kid_user.save!
    @kid = Act::Participant.create!(name: 'Jan', last_name: 'Kid', nickname: '', grade: 7,
                                    email: 'kid@x.cz', user_id: kid_user.id, activated: 'desact')
    @ep = Act::EventParticipant.create!(event_id: @event.id, participant_id: @kid.id,
                                        status: 'yes', chosen: 'participant')
  end

  test "set_role stores opposite of displayed (guessed) role" do
    assert_nil @ep.role
    assert_equal 'participant', @ep.role_display   # odhad z ročníku 7
    assert @ep.role_guessed?

    sign_in @morg
    post :set_role, params: { event_id: @event.id, participant_id: @kid.id }
    # redirect s kotvou na řádek, ať stránka neskočí na začátek
    assert_redirected_to act_event_edit_participants_path(@event.id, anchor: "ep-#{@kid.id}")
    @ep.reload
    assert_equal 'org', @ep.role                    # opak odhadu, uloženo
    assert_not @ep.role_guessed?

    post :set_role, params: { event_id: @event.id, participant_id: @kid.id }
    assert_equal 'participant', @ep.reload.role     # toggle zpět
  end
end
