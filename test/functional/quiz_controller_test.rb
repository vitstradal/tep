require 'test_helper'

class QuizControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @quiz = Quiz.create!(name: 'kviz-pi', quiz_type: 'quiz',
                         data: { 'correct' => { '1' => '42' } })
  end

  test "answer creates friend lazily and stores answer" do
    post :answer, params: { name: 'kviz-pi', nick: 'Petr', question_no: 1, answer: '42' }
    json = JSON.parse(response.body)
    assert json['ok']
    assert_equal true, json['correct']
    f = Friend.find_by(uuid: json['uuid'])
    assert_equal 'Petr', f.nick
    assert_equal '42', QuizAnswer.find_by(quiz: @quiz, friend: f, question_no: 1).answer
  end

  test "answer upserts on repeat" do
    f = Friend.create!(nick: 'Petr')
    post :answer, params: { name: 'kviz-pi', uuid: f.uuid, question_no: 1, answer: 'a' }
    post :answer, params: { name: 'kviz-pi', uuid: f.uuid, question_no: 1, answer: 'b' }
    assert_equal 1, QuizAnswer.where(quiz: @quiz, friend: f).count
    assert_equal 'b', QuizAnswer.find_by(quiz: @quiz, friend: f).answer
  end

  test "closed quiz rejects answers" do
    @quiz.update!(closes_on: Date.yesterday)
    post :answer, params: { name: 'kviz-pi', nick: 'Petr', question_no: 1, answer: 'x' }
    assert_response :forbidden
  end

  test "advent locked day rejects answers" do
    Quiz.create!(name: 'advent', quiz_type: 'advent',
                 opens_on: Date.today, closes_on: Date.today + 30)
    post :answer, params: { name: 'advent', nick: 'P', question_no: 5, answer: 'x' }
    assert_response :forbidden
  end

  test "honeypot silently drops" do
    post :answer, params: { name: 'kviz-pi', nick: 'Bot', question_no: 1, answer: 'x', website: 'spam' }
    assert_equal 0, QuizAnswer.count
    assert JSON.parse(response.body)['ok']   # bot nepozná, že neuspěl
  end

  test "signed in user answers via canonical friend" do
    u = User.new(email: 'q@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    sign_in u
    post :answer, params: { name: 'kviz-pi', question_no: 1, answer: '42' }
    assert_equal u.reload.friend.id, QuizAnswer.last.friend_id
  end

  test "vysledky renders scoreboard when public" do
    @quiz.update!(data: @quiz.data.merge('public_results' => true))
    f1 = Friend.create!(nick: 'Petr')
    f2 = Friend.create!(nick: 'Petr')
    QuizAnswer.create!(quiz: @quiz, friend: f1, question_no: 1, answer: '42')
    QuizAnswer.create!(quiz: @quiz, friend: f2, question_no: 1, answer: 'ne')
    get :vysledky, params: { name: 'kviz-pi' }
    assert_response :success
    assert_match 'Petr', response.body
    assert_match f1.discriminator, response.body
  end

  test "vysledky of private quiz is forbidden for anonymous" do
    get :vysledky, params: { name: 'kviz-pi' }
    assert_response :forbidden
  end

  test "vysledky of private quiz is forbidden for plain user" do
    u = User.new(email: 'plain@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    sign_in u
    get :vysledky, params: { name: 'kviz-pi' }
    assert_response :forbidden
  end

  test "vysledky of private quiz works for org" do
    u = User.new(email: 'org@x.cz', password: 'password123', roles: [:org])
    u.skip_confirmation!
    u.save!
    sign_in u
    get :vysledky, params: { name: 'kviz-pi' }
    assert_response :success
  end

  test "unknown quiz 404" do
    post :answer, params: { name: 'neni', question_no: 1, answer: 'x' }
    assert_response :not_found
  end

  test "show renders poll page with form" do
    Quiz.create!(name: 'testquiz', quiz_type: 'poll', title: 'Testovací anketka',
                 data: { 'question' => 'Napiš, co tě napadne', 'public_results' => true })
    get :show, params: { name: 'testquiz' }
    assert_response :success
    assert_match 'Testovací anketka', response.body
    assert_match 'Napiš, co tě napadne', response.body
    assert_match 'quiz-form', response.body
    assert_match 'vysledky', response.body   # veřejné výsledky → odkaz je
  end

  test "show of quiz with private results has no results link" do
    Quiz.create!(name: 'tajny', quiz_type: 'quiz', title: 'Tajný kvíz')
    get :show, params: { name: 'tajny' }
    assert_response :success
    assert_no_match(/vysledky/, response.body)
  end

  test "show of unknown quiz 404" do
    get :show, params: { name: 'neni' }
    assert_response :not_found
  end

  test "answers is forbidden for anonymous and plain user" do
    f = Friend.create!(nick: 'Tajny')
    QuizAnswer.create!(quiz: @quiz, friend: f, question_no: 1, answer: 'soukrome')

    get :answers, params: { name: 'kviz-pi' }
    assert_response :redirect   # anonym -> login
    assert_no_match(/soukrome/, response.body)

    u = User.new(email: 'plain2@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    sign_in u
    get :answers, params: { name: 'kviz-pi' }   # bez org role -> chybová stránka
    assert_no_match(/soukrome/, response.body)
    assert_match(/ERR-/, response.body)
  end

  test "answers returns raw answers for org" do
    org = User.new(email: 'org2@x.cz', password: 'password123', roles: [:org])
    org.skip_confirmation!
    org.save!
    f = Friend.create!(nick: 'Kid')
    QuizAnswer.create!(quiz: @quiz, friend: f, question_no: 7,
                       answer: '{"components":[]}', data: { 'gates' => 5 })
    sign_in org
    get :answers, params: { name: 'kviz-pi' }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    row = json.first
    assert_equal 'Kid', row['nick']
    assert_equal 7, row['question_no']
    assert_equal '{"components":[]}', row['answer']
    assert_equal 5, row['data']['gates']
    assert_equal 'anonymous', row['status']
    assert row['discriminator'].present?
    assert row['updated_at'].present?
  end

  test "answers of unknown quiz 404 for org" do
    org = User.new(email: 'org3@x.cz', password: 'password123', roles: [:org])
    org.skip_confirmation!
    org.save!
    sign_in org
    get :answers, params: { name: 'neni' }
    assert_response :not_found
  end

  test "show of closed quiz says closed" do
    Quiz.create!(name: 'zavreny', quiz_type: 'poll', closes_on: Date.yesterday)
    get :show, params: { name: 'zavreny' }
    assert_response :success
    assert_match 'uzavřen', response.body
  end
end
