require 'test_helper'

class AdventomatControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  PRAGUE = ActiveSupport::TimeZone['Europe/Prague']
  PNG = "\x89PNG\r\n\x1A\nfake".b

  setup do
    @dir = Dir.mktmpdir
    Rugged::Repository.init_at(@dir, :bare)
    @saved = Giwi.giwis.dup
    @piki = Giwi.new('piki', { path: @dir, url: 'piki', ext: '.wiki', read: :org })
    Giwi.giwis.replace(piki: @piki)
    days = (1..24).map { |n| "== #{n} ==\nKolik je #{n} + 12?\n#{'[[Image(5.png)]]' if n == 5}\nvýsledek: #{n + 12}\npoznámka: tajné\n" }.join("\n")
    @piki.set_files({ 'adventomat/2026/index.wiki' => "= A =\n\n#{days}\n== bonus ==\nBonus?\nvýsledek: 37\n\n== odměna ==\nHurá!\n[[Image(odmena.png)]]\n",
                      'adventomat/2026/5.png' => PNG, 'adventomat/2026/odmena.png' => PNG,
                      'adventomat/2025/index.wiki' => "== 1 ==\nStaré\nvýsledek: 7\n" }, 'init', 'A <a@b.cz>')
  end

  teardown do
    Giwi.giwis.replace(@saved)
    FileUtils.remove_entry(@dir)
  end

  def at(day, h = 12, m = 0, &blk)
    travel_to(PRAGUE.local(2026, 12, day, h, m), &blk)
  end

  def json
    JSON.parse(response.body)
  end

  def user(email, org: false)
    u = User.new(email: email, password: 'password123', roles: org ? [:org] : [:user])
    u.skip_confirmation!
    u.save!
    u
  end

  def solve(friend, *days, at: Time.current)
    quiz = Quiz.find_or_create_by!(name: 'advent-2026') { |q| q.quiz_type = 'advent' }
    days.each { |n| QuizAnswer.create!(quiz: quiz, friend: friend, question_no: n, answer: 'x', data: { 'solved_at' => at.iso8601 }) }
  end

  test "calendar before December is all locked and leaks nothing" do
    travel_to(PRAGUE.local(2026, 11, 30, 12)) do
      get :kalendar, params: { name: 'advent-2026' }
      assert_response :success
      assert_equal 25, json['days'].size
      assert json['days'].all? { |d| d['state'] == 'locked' }
      assert_no_match(/Kolik|tajné|výsledek|result/, response.body)
      assert_equal PRAGUE.local(2026, 12, 1, 3, 14).iso8601, json['next_open_at']
      assert_equal 'no-store', response.headers['Cache-Control']
    end
  end

  test "day opens at 3:14 and only its text goes out" do
    at(1, 3, 13) do
      get :den, params: { name: 'advent-2026', den: '1' }
      assert_response :forbidden
      assert_no_match 'Kolik', response.body
    end
    at(1, 3, 14) do
      get :den, params: { name: 'advent-2026', den: '1' }
      assert_response :success
      assert_match 'Kolik je 1 + 12?', json['html']
      assert_no_match(/13|tajné/, json['html'])
      get :den, params: { name: 'advent-2026', den: 'bonus' }
      assert_response :forbidden
    end
  end

  test "image goes through the tunnel only for an open day" do
    at(4) do
      get :obrazek, params: { name: 'advent-2026', soubor: '5.png' }
      assert_response :forbidden
    end
    at(5) do
      get :obrazek, params: { name: 'advent-2026', soubor: '5.png' }
      assert_response :success
      assert_equal 'image/png', response.media_type
      assert_equal PNG, response.body.b
      get :obrazek, params: { name: 'advent-2026', soubor: '../2025/index.wiki' }
      assert_response :forbidden
      get :obrazek, params: { name: 'advent-2026', soubor: 'odmena.png' }
      assert_response :forbidden
    end
  end

  test "old year is open to everyone, unknown year is 404" do
    get :den, params: { name: 'advent-2025', den: '1' }
    assert_response :success
    get :kalendar, params: { name: 'advent-2031' }
    assert_response :not_found
  end

  test "answer: number check, solved stays solved, locked day refused" do
    at(3) do
      post :answer, params: { name: 'advent-2026', nick: 'Petr', question_no: 2, answer: 'čtrnáct' }
      assert_response :unprocessable_entity
      assert_equal 0, QuizAnswer.count
      post :answer, params: { name: 'advent-2026', nick: 'Petr', question_no: 2, answer: ' 1 4 ' }
      assert_equal true, json['correct']
      uuid = json['uuid']
      post :answer, params: { name: 'advent-2026', uuid: uuid, question_no: 2, answer: '15' }
      assert_equal false, json['correct']
      assert_equal true, json['solved']
      assert_equal '14', QuizAnswer.last.answer
      post :answer, params: { name: 'advent-2026', uuid: uuid, question_no: 4, answer: '16' }
      assert_response :forbidden
      get :moje, params: { name: 'advent-2026', uuid: uuid }
      assert_equal [2], json['solved']
      assert_equal 'Petr', json['nick']
      get :kalendar, params: { name: 'advent-2026', uuid: uuid }
      assert_equal 'solved', json['days'].find { |d| d['no'] == 2 }['state']
      assert_equal 'open', json['days'].find { |d| d['no'] == 3 }['state']
    end
  end

  test "signed-in player sees solved days on any computer, guest uuid of an account is ignored" do
    u = user('kid@x.cz')
    sign_in u
    at(3) { post :answer, params: { name: 'advent-2026', question_no: 1, answer: '13' } }
    sign_out u
    get :moje, params: { name: 'advent-2026', uuid: u.friend.uuid }
    assert_equal [], json['solved']
    sign_in u
    get :moje, params: { name: 'advent-2026' }
    assert_equal [1], json['solved']
  end

  test "table counts solved before the close, at least four, sorted" do
    a = Friend.create!(nick: 'Ája')
    b = Friend.create!(nick: 'bob')
    c = Friend.create!(nick: 'Cyril')
    late = Friend.create!(nick: 'Pozdě')
    solve(a, 1, 2, 3, 4, at: PRAGUE.local(2026, 12, 5))
    solve(b, 1, 2, 3, 4, 5, at: PRAGUE.local(2026, 12, 6))
    solve(c, 1, 2, 3, at: PRAGUE.local(2026, 12, 6))
    solve(late, 1, 2, 3, 4, at: PRAGUE.local(2026, 12, 27))
    at(28) do
      get :kalendar, params: { name: 'advent-2026' }
      assert_equal [['bob', 5], ['Ája', 4]], json['table'].map { |r| [r['nick'], r['count']] }
      assert json['closed']
    end
  end

  test "reward only after all days" do
    f = Friend.create!(nick: 'Vše')
    solve(f, *(1..24).to_a)
    at(26) do
      get :odmena, params: { name: 'advent-2026', uuid: f.uuid }
      assert_response :forbidden
      get :obrazek, params: { name: 'advent-2026', soubor: 'odmena.png', uuid: f.uuid }
      assert_response :forbidden
      solve(f, 25)
      get :odmena, params: { name: 'advent-2026', uuid: f.uuid }
      assert_match 'Hurá!', json['html']
      get :obrazek, params: { name: 'advent-2026', soubor: 'odmena.png', uuid: f.uuid }
      assert_response :success
    end
  end

  test "org debug shifts time and answers are not stored" do
    sign_in user('org@x.cz', org: true)
    at(1) do
      post :debug, params: { name: 'advent-2026', now: '2026-12-24T03:14' }
      assert json['ok']
      get :den, params: { name: 'advent-2026', den: '24' }
      assert_response :success
      post :answer, params: { name: 'advent-2026', question_no: 24, answer: '36' }
      assert json['debug']
      assert_equal true, json['correct']
      assert_equal 0, QuizAnswer.count
      get :moje, params: { name: 'advent-2026' }
      assert_equal [24], json['solved']
      post :debug, params: { name: 'advent-2026', now: '2026-12-24T03:13' }
      get :den, params: { name: 'advent-2026', den: '24' }
      assert_response :forbidden
      post :debug, params: { name: 'advent-2026', off: '1' }
      get :moje, params: { name: 'advent-2026' }
      assert_equal [], json['solved']
      get :den, params: { name: 'advent-2026', den: '24' }
      assert_response :forbidden
    end
  end

  test "debug next jumps 10 s before the next opening and debug time runs on" do
    sign_in user('org@x.cz', org: true)
    travel_to PRAGUE.local(2026, 12, 1, 12)
    post :debug, params: { name: 'advent-2026', next: '1' }
    assert_equal PRAGUE.local(2026, 12, 2, 3, 13, 50).iso8601, json['debug']['now']
    get :den, params: { name: 'advent-2026', den: '2' }
    assert_response :forbidden
    travel 11.seconds
    get :den, params: { name: 'advent-2026', den: '2' }
    assert_response :success
    post :debug, params: { name: 'advent-2026', now: '2026-12-25T00:00' }
    post :debug, params: { name: 'advent-2026', next: '1' }
    assert_response :unprocessable_entity
  end

  test "debug and kontrola are for orgs only" do
    post :debug, params: { name: 'advent-2026', now: '2026-12-24T03:14' }
    assert_redirected_to %r{/users/sign_in}
    assert_nil session[:adventomat_debug]
    sign_in user('kid@x.cz')
    get :kontrola, params: { name: 'advent-2026' }
    assert_no_match 'Otevře se', response.body
  end

  test "kontrola lists problems first" do
    @piki.set_files({ 'adventomat/2027/index.wiki' => "== 1 ==\nA\nvýsledek: x\n" }, 'k', 'A <a@b.cz>')
    sign_in user('org@x.cz', org: true)
    get :kontrola, params: { name: 'advent-2027' }
    assert_response :success
    assert response.body.index('výsledek není celé číslo') < response.body.index('Otevře se')
    assert_match 'den chybí', response.body
  end

  test "review is for orgs: tasks, results, permalinks and images before opening" do
    travel_to(PRAGUE.local(2026, 11, 20, 12)) do
      sign_in user('kid@x.cz')
      get :review, params: { name: 'advent-2026' }
      assert_no_match 'Kolik je', response.body
      get :obrazek, params: { name: 'advent-2026', soubor: '5.png', nahled: 1 }
      assert_response :forbidden
      sign_out :user
      sign_in user('org@x.cz', org: true)
      get :review, params: { name: 'advent-2026' }
      assert_response :success
      assert_match 'id="den-5"', response.body
      assert_match 'id="den-bonus"', response.body
      assert_match 'Kolik je 5 + 12?', response.body
      assert_match 'obrazek/5.png?nahled=1', response.body
      assert_match(/adv-spoiler[^>]*>\s*17/, response.body)
      get :obrazek, params: { name: 'advent-2026', soubor: '5.png', nahled: 1 }
      assert_response :success
      get :obrazek, params: { name: 'advent-2026', soubor: '5.png' }
      assert_response :forbidden
      get :obrazek, params: { name: 'advent-2026', soubor: 'index.wiki', nahled: 1 }
      assert_response :forbidden
    end
  end
end
