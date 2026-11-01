require 'test_helper'

class SosnaSolutionOrgAccessTest < ActionController::TestCase
  tests Sosna::SolutionController
  include Devise::Test::ControllerHelpers

  setup do
    problem = Sosna::Problem.create!(annual: 99, level: 'pi', round: 1, problem_no: 1)
    solver = Sosna::Solver.create!(name: 'Jan', last_name: 'Novák', annual: '99', email: 'jan@x.cz',
                                   where_to_send: 'school', grade_num: '9')
    Sosna::Solution.create!(problem: problem, solver: solver, score: 5)
  end

  def login(*roles)
    u = User.new(email: "#{roles.last}@x.cz", password: 'password123', roles: [:user, *roles])
    u.skip_confirmation!
    u.save!
    sign_in u
  end

  test "org sees morg-only buttons disabled" do
    login :org
    get :index, params: { roc: '99', level: 'pi', se: '1' }
    assert_response :success
    assert_no_match %r{action="/sosna/solution/update_results}, response.body
    assert_no_match %r{paper=yes|penalisation=yes}, response.body
    assert_select 'button.disabled', text: /Vygenerovat výsledky/
    assert_select 'button.disabled', text: /Editovat penalizaci/
  end

  test "morg gets working buttons" do
    login :org, :morg
    get :index, params: { roc: '99', level: 'pi', se: '1' }
    assert_match %r{action="/sosna/solution/update_results}, response.body
    assert_match(/penalisation=yes/, response.body)
  end
end
