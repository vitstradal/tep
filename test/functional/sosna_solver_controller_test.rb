require 'test_helper'

class SosnaSolverControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Sosna::SolverController

  # platné parametry přihlášky (papírové zasílání domů)
  def solver_params(email, grade: 5, paper_jr: '0', paper_pi: '0')
    {
      sosna_solver: { name: 'Jan', last_name: 'Novak', email: email,
                      birth: "1.1.#{Date.today.year - 12}", grade: "#{grade}. třída",
                      grade_num: grade.to_s, where_to_send: 'home', street: 'X', num: '1',
                      city: 'Praha', psc: '100 00', state: 'cz',
                      paper_jr: paper_jr, paper_pi: paper_pi },
      souhlasim: '1',
      school: { id: 'jina' },
      sosna_school: { name: 'ZS Test', short: 'ZST', street: 'S', num: '2',
                      city: 'Praha', psc: '100 00', state: 'cz' }
    }
  end

  test "registration stores paper level choices" do
    Sosna::Config.create!(key: 'annual', value: '33')
    post :create, params: solver_params('junior@seznam.cz', grade: 5, paper_jr: '1', paper_pi: '0')
    solver = Sosna::Solver.find_by(email: 'junior@seznam.cz')
    assert solver, 'řešitel se má založit'
    assert_equal true,  solver.paper_jr
    assert_equal false, solver.paper_pi
  end

  test "registration requires at least one paper level for paper delivery" do
    Sosna::Config.create!(key: 'annual', value: '33')
    post :create, params: solver_params('nic@seznam.cz', grade: 5)
    assert_nil Sosna::Solver.find_by(email: 'nic@seznam.cz')
    assert_redirected_to action: :new   # zpět do formuláře s chybou
  end

  test "registration drops junior leaflet above 6th grade" do
    Sosna::Config.create!(key: 'annual', value: '33')
    post :create, params: solver_params('velky@seznam.cz', grade: 8, paper_jr: '1', paper_pi: '1')
    solver = Sosna::Solver.find_by(email: 'velky@seznam.cz')
    assert solver
    assert_equal false, solver.paper_jr, 'junior je jen do 6. ročníku'
    assert_equal true,  solver.paper_pi
  end

  test "solver registration takes over unverified friend account" do
    # neověřený přítel Pikomatu (jako po friend#register)
    friend_user = User.new(email: 'kid@seznam.cz', password: SecureRandom.hex(16))
    friend_user.skip_confirmation_notification!
    friend_user.save!
    Friend.create!(nick: 'Kid', user: friend_user)
    Sosna::Config.create!(key: 'annual', value: '33')

    post :create, params: {
      sosna_solver: { name: 'Jan', last_name: 'Novak', email: 'kid@seznam.cz',
                      birth: "1.1.#{Date.today.year - 12}", grade: 'sedmá třída',
                      grade_num: '7', where_to_send: 'home', street: 'X', num: '1',
                      city: 'Praha', psc: '100 00', state: 'cz', paper_pi: '1' },
      souhlasim: '1',
      school: { id: 'jina' },
      sosna_school: { name: 'ZS Test', short: 'ZST', street: 'S', num: '2',
                      city: 'Praha', psc: '100 00', state: 'cz' }
    }
    assert_redirected_to action: :create_tnx, send_first: true

    friend_user.reload
    assert friend_user.confirmed_at.present?, 'převzatý účet má být potvrzen'
    assert friend_user.user?, 'převzatý účet má dostat roli :user'
    solver = Sosna::Solver.find_by(email: 'kid@seznam.cz')
    assert_equal friend_user.id, solver.user_id
  end
end
