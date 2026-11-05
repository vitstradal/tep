require 'test_helper'

class ActParticipantBirthTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::ParticipantsController

  setup do
    @tz = ENV['TZ']
    ENV['TZ'] = 'Europe/Prague'
    @user = User.new(email: 'kid@x.cz', password: 'password123', roles: [:user])
    @user.skip_confirmation!
    @user.save!
    @p = Act::Participant.create!(name: 'Jan', last_name: 'Kid', nickname: '', grade: 7, email: 'kid@x.cz',
                                  user_id: @user.id, activated: 'full', phone: '1', parent_email: 'r@x.cz',
                                  parent_phone: '2', birth: Date.new(2014, 1, 1), address: 'A', birth_number: '1',
                                  health_insurance: '111', sex: 'male')
    sign_in @user
  end

  teardown { ENV['TZ'] = @tz }

  test "birth date survives save and repeated edits without shifting" do
    patch :update, params: { participant_id: @p.id, participant: { birth: '2014-06-18' } }
    assert_equal Time.utc(2014, 6, 18), @p.reload.birth
    3.times do
      get :edit, params: { participant_id: @p.id }
      value = css_select('input#participant_birth').first['value']
      assert_equal '2014-06-18', value
      patch :update, params: { participant_id: @p.id, participant: { birth: value } }
    end
    assert_equal Time.utc(2014, 6, 18), @p.reload.birth
    assert_equal '18.6.2014', @p.birth_str
  end
end
