require 'test_helper'

class ActParticipantsTshirtTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Act::ParticipantsController

  setup do
    @user = User.new(email: 'kid@x.cz', password: 'password123', roles: [:user])
    @user.skip_confirmation!
    @user.save!
    @p = Act::Participant.create!(name: 'Jan', last_name: 'Kid', nickname: '', grade: 7, email: 'kid@x.cz',
                                  user_id: @user.id, activated: 'full', tshirt: 'S', phone: '1', parent_email: 'r@x.cz',
                                  parent_phone: '2', birth: Date.new(2014, 1, 1), address: 'A', birth_number: '1',
                                  health_insurance: '111', sex: 'male')
    sign_in @user
  end

  test "participant sees and edits own t-shirt size" do
    get :show, params: { participant_id: @p.id }
    assert_match 'Velikost trička', response.body
    get :edit, params: { participant_id: @p.id }
    assert_select 'input#participant_tshirt[value="S"]'
    patch :update, params: { participant_id: @p.id, participant: { tshirt: 'L' } }
    assert_equal 'L', @p.reload.tshirt
  end
end
