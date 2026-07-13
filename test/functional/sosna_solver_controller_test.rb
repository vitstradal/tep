require 'test_helper'

class SosnaSolverControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Sosna::SolverController

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
                      city: 'Praha', psc: '100 00', state: 'cz' },
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
