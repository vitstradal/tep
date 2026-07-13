require 'test_helper'

class FriendControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  def make_user(email)
    u = User.new(email: email, password: 'password123')
    u.skip_confirmation!
    u.save!
    u
  end

  test "hello creates friend and returns uuid" do
    post :hello, params: { nick: 'Petr' }
    json = JSON.parse(response.body)
    assert json['uuid'].present?
    assert_equal 'Petr', json['nick']
    assert_equal 'anonymous', json['status']
    assert Friend.find_by(uuid: json['uuid'])
  end

  test "hello with known uuid updates nick" do
    f = Friend.create!(nick: 'Petr')
    post :hello, params: { uuid: f.uuid, nick: 'PetrII' }
    assert_equal 'PetrII', f.reload.nick
    assert f.last_seen_at.present?
  end

  test "hello without nick fails" do
    post :hello, params: { nick: '' }
    assert_response :unprocessable_entity
  end

  test "status for unknown uuid" do
    get :status, params: { uuid: 'neexistuje' }
    assert_equal 'unknown', JSON.parse(response.body)['status']
  end

  test "status for anonymous friend" do
    f = Friend.create!(nick: 'Petr')
    get :status, params: { uuid: f.uuid }
    json = JSON.parse(response.body)
    assert_equal 'anonymous', json['status']
    assert_equal 'Petr', json['nick']
  end

  test "status signed in returns canonical friend and wins over localStorage" do
    u = make_user('a@x.cz')
    mine = Friend.create!(nick: 'Muj', user: u)
    other = Friend.create!(nick: 'Cizi')
    sign_in u
    get :status, params: { uuid: other.uuid }
    json = JSON.parse(response.body)
    assert_equal mine.uuid, json['uuid']
    assert json['signed_in']
    assert json['merge_candidate']
  end

  test "status signed in creates canonical friend when missing" do
    u = make_user('b@x.cz')
    sign_in u
    get :status
    json = JSON.parse(response.body)
    assert_equal 'verified', json['status']
    assert_equal u.reload.friend.uuid, json['uuid']
  end

  test "claim adopts anonymous friend when user has none" do
    u = make_user('c@x.cz')
    f = Friend.create!(nick: 'Anonym')
    sign_in u
    post :claim, params: { uuid: f.uuid }
    assert_equal u.id, f.reload.user_id
  end

  test "claim merges answers into canonical friend" do
    u = make_user('d@x.cz')
    mine = Friend.create!(nick: 'Muj', user: u)
    other = Friend.create!(nick: 'Cizi')
    q = Quiz.create!(name: 'k1')
    QuizAnswer.create!(quiz: q, friend: other, question_no: 1, answer: 'a')
    QuizAnswer.create!(quiz: q, friend: mine,  question_no: 2, answer: 'b')
    QuizAnswer.create!(quiz: q, friend: other, question_no: 2, answer: 'kolize')
    sign_in u
    post :claim, params: { uuid: other.uuid }
    assert_nil Friend.find_by(uuid: other.uuid)
    answers = QuizAnswer.where(friend_id: mine.id).order(:question_no)
    assert_equal [1, 2], answers.map(&:question_no)
    assert_equal 'b', answers.last.answer   # kanonická odpověď vyhrává
  end

  test "claim requires login" do
    f = Friend.create!(nick: 'Anonym')
    post :claim, params: { uuid: f.uuid }
    assert_response :redirect
  end
end
