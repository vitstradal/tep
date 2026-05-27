require 'test_helper'

class TepControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  def make_user(email, roles = [])
    u = User.new(email: email, password: 'password123', password_confirmation: 'password123')
    u.skip_confirmation!
    u.save!
    roles.each { |r| u.roles << r }
    u.save!
    u
  end

  def make_solver(email, user_id, annual)
    Sosna::Solver.create!(name: 'Jan', last_name: 'Novak', annual: annual,
                          email: email, user_id: user_id, where_to_send: 'school')
  end

  def make_participant(email, user_id)
    Act::Participant.create!(name: 'Jan', last_name: 'Novak', nickname: '',
                             email: email, user_id: user_id, activated: 'desact')
  end

  setup do
    @admin = make_user('admin@x.cz', [:admin])
    sign_in @admin

    @user = make_user('old@x.cz')
    @solver_match = make_solver('old@x.cz', @user.id, '33')   # default checked
    @solver_other = make_solver('old@x.cz', @user.id, '31')   # leave unchecked
    @participant  = make_participant('old@x.cz', @user.id)
  end

  test "successful change propagates only to checked places" do
    post :user_change_email, params: {
      id: @user.id, email: 'new@x.cz',
      solver_ids: [@solver_match.id], change_participant: '1'
    }
    assert_equal 'new@x.cz', @user.reload.email
    assert_equal 'new@x.cz', @solver_match.reload.email
    assert_equal 'new@x.cz', @participant.reload.email
    # unchecked solver is left untouched
    assert_equal 'old@x.cz', @solver_other.reload.email
    assert flash[:success].present?
  end

  test "collision with another user blocks the change" do
    make_user('taken@x.cz')
    post :user_change_email, params: { id: @user.id, email: 'taken@x.cz' }
    assert_equal 'old@x.cz', @user.reload.email
    assert flash[:alert].present?
  end

  test "collision with another user's solver blocks the change" do
    other = make_user('other@x.cz')
    make_solver('solvertaken@x.cz', other.id, '33')
    post :user_change_email, params: { id: @user.id, email: 'solvertaken@x.cz' }
    assert_equal 'old@x.cz', @user.reload.email
    assert flash[:alert].present?
  end

  test "collision with another user's participant blocks the change" do
    other = make_user('other@x.cz')
    make_participant('parttaken@x.cz', other.id)
    post :user_change_email, params: { id: @user.id, email: 'parttaken@x.cz' }
    assert_equal 'old@x.cz', @user.reload.email
    assert flash[:alert].present?
  end

  test "own records are not treated as a collision" do
    # change to an email already held only by this user's own records
    post :user_change_email, params: { id: @user.id, email: 'old@x.cz' }
    assert_equal 'old@x.cz', @user.reload.email
    assert flash[:success].present?
  end

  test "invalid email is rejected" do
    post :user_change_email, params: { id: @user.id, email: 'not-an-email' }
    assert_equal 'old@x.cz', @user.reload.email
    assert flash[:alert].present?
  end
end
