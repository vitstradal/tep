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
    assert_equal false, json['org']
  end

  test "status signed in as org reports org flag" do
    u = User.new(email: 'org@x.cz', password: 'password123', roles: [:org])
    u.skip_confirmation!
    u.save!
    sign_in u
    get :status
    json = JSON.parse(response.body)
    assert_equal true, json['org']
  end

  test "status for anonymous has no org flag" do
    f = Friend.create!(nick: 'Petr')
    get :status, params: { uuid: f.uuid }
    assert_not JSON.parse(response.body).key?('org')
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

  test "claim keeps a solved advent day from the guest" do
    u = make_user('e@x.cz')
    mine = Friend.create!(nick: 'Muj', user: u)
    other = Friend.create!(nick: 'Host')
    q = Quiz.create!(name: 'advent-2026', quiz_type: 'advent')
    QuizAnswer.create!(quiz: q, friend: mine,  question_no: 1, answer: '5')
    QuizAnswer.create!(quiz: q, friend: other, question_no: 1, answer: '13', data: { 'solved_at' => '2026-12-01T10:00:00+01:00' })
    QuizAnswer.create!(quiz: q, friend: mine,  question_no: 2, answer: '14', data: { 'solved_at' => '2026-12-02T10:00:00+01:00' })
    QuizAnswer.create!(quiz: q, friend: other, question_no: 2, answer: '99', data: { 'solved_at' => '2026-12-02T11:00:00+01:00' })
    sign_in u
    post :claim, params: { uuid: other.uuid }
    answers = QuizAnswer.where(friend_id: mine.id).order(:question_no)
    assert_equal %w[13 14], answers.map(&:answer)
  end

  test "claim requires login" do
    f = Friend.create!(nick: 'Anonym')
    post :claim, params: { uuid: f.uuid }
    assert_response :redirect
  end

  # založí neověřeného přítele stejně jako akce register
  def make_unverified_friend(nick, email)
    u = User.new(email: email, password: SecureRandom.hex(16))
    u.skip_confirmation_notification!
    u.save!
    f = Friend.create!(nick: nick, user: u)
    u.send_confirmation_instructions
    [f, u]
  end

  def captcha_sum
    get :register_form
    assert_response :success
    assert_no_match(/\d+\s*\+\s*\d+/, response.body.gsub(/<[^>]+>/, ''))
    session[:friend_captcha]['sum']
  end

  test "register needs the captcha sum and a human pause" do
    f = Friend.create!(nick: 'Petr')
    sum = captcha_sum
    assert_no_difference ['User.count', 'ActionMailer::Base.deliveries.size'] do
      post :register, params: { uuid: f.uuid, email: 'obet@x.cz' }
      post :register, params: { uuid: f.uuid, email: 'obet@x.cz', captcha: sum }
    end
    sum = captcha_sum
    travel 5.seconds do
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        post :register, params: { uuid: f.uuid, email: 'obet@x.cz', captcha: sum + 1 }
        post :register, params: { uuid: f.uuid, email: 'obet@x.cz', captcha: sum }
      end
    end
    sum = captcha_sum
    travel 5.seconds do
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        post :register, params: { uuid: f.uuid, email: 'obet@x.cz', captcha: sum, website: 'http://spam' }
      end
    end
    assert_nil f.reload.user_id
  end

  test "register with captcha sends one mail per address a day" do
    f = Friend.create!(nick: 'Petr')
    sum = captcha_sum
    travel 5.seconds do
      assert_difference ['User.count', 'ActionMailer::Base.deliveries.size'], 1 do
        post :register, params: { uuid: f.uuid, email: 'novy@x.cz', captcha: sum }
      end
    end
    assert_equal 'novy@x.cz', f.reload.user.email
    sum = captcha_sum
    travel 10.seconds do
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        post :register, params: { email: 'novy@x.cz', nick: 'Jiný', captcha: sum }
      end
    end
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      post :resend, params: { uuid: f.uuid }
    end
  end

  test "finish sets password confirms and signs in" do
    f, u = make_unverified_friend('Petr', 'fin@x.cz')
    token = u.reload.confirmation_token
    get :finish, params: { token: token }
    assert_response :success
    post :do_finish, params: { token: token, password: 'tajneheslo1', password_confirmation: 'tajneheslo1' }
    u.reload
    assert u.confirmed_at.present?
    assert u.valid_password?('tajneheslo1')
    assert_equal 'verified', f.reload.status
  end

  test "finish with bad token fails" do
    get :finish, params: { token: 'spatny' }
    assert_response :redirect
    assert flash[:alerts].present?
  end

  test "resend sends confirmation again" do
    f, _u = make_unverified_friend('Petr', 're@x.cz')
    travel 2.hours do
      assert_difference 'ActionMailer::Base.deliveries.size', 1 do
        post :resend, params: { uuid: f.uuid }
      end
    end
  end
end
