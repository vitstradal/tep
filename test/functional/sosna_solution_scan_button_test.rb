require 'test_helper'

# Tlačítko skeneru (fotoaparát) u formuláře pro nahrání řešení na „Moje řešení“.
class SosnaSolutionScanButtonTest < ActionController::TestCase
  tests Sosna::SolutionController
  include Devise::Test::ControllerHelpers

  setup do
    { annual: '99', round: '1', show1: 'yes', deadline1: (Date.today + 7).to_s }.each do |k, v|
      Sosna::Config.create!(key: k.to_s, value: v)
    end
    @p1 = Sosna::Problem.create!(annual: 99, level: 'pi', round: 1, problem_no: 1, title: 'Krokodýl')
    @p2 = Sosna::Problem.create!(annual: 99, level: 'pi', round: 1, problem_no: 2, title: 'Žirafa "dlouhá"')
  end

  def login(roles, grade: '9')
    user = User.new(email: "#{roles.last}@x.cz", password: 'password123', roles: roles)
    user.skip_confirmation!
    user.save!
    sign_in user
    Sosna::Solver.create!(name: 'Jan', last_name: 'Novák', annual: '99', email: 'jan@x.cz',
                          where_to_send: 'school', grade_num: grade, user_id: user.id)
  end

  def solution_for(solver, problem)
    Sosna::Solution.where(solver_id: solver.id, problem_id: problem.id).take!
  end

  test "resitel v otevrenem kole ma u kazde ulohy tlacitko na formular te ulohy" do
    solver = login([:user])
    get :user_index, params: { roc: '99', level: 'pi', se: '1' }
    assert_response :success

    assert_select 'button.solution-scan', 2
    [[@p1, 'Krokodýl'], [@p2, 'Žirafa "dlouhá"']].each do |problem, title|
      form_id = "edit_sosna_solution_#{solution_for(solver, problem).id}"
      assert_select "form##{form_id} input[type=file][name='sosna_solution[solution_file][]']", 1
      assert_select "button.solution-scan[data-form='##{form_id}']", 1 do |buttons|
        button = buttons.first
        assert_equal title, button['data-title']
        assert_equal 'button', button['type']
        assert_equal SolutionScan::OPENCV_JS, button['data-opencv']
        assert_equal SolutionScan.scanner_js, button['data-scanner']
        assert_includes button['class'].split, 'hide'
      end
      assert_select "form##{form_id} button.solution-scan[type=button]", 1
    end
    assert_select '#solution-scan-modal', 1
  end

  test "cesty ke knihovnam skeneru" do
    assert_match %r{\A/javascripts/opencv-\d+\.\d+\.\d+\.js\z}, SolutionScan::OPENCV_JS
    makefile = File.read(Rails.root.join('Makefile'))
    assert_equal "/javascripts/opencv-#{makefile[/^OPENCV_VERSION = (\S+)$/, 1]}.js", SolutionScan::OPENCV_JS
    mtime = File.mtime(Rails.public_path.join('javascripts', 'scanner.js')).to_i
    assert_equal "/javascripts/scanner.js?v=#{mtime}", SolutionScan.scanner_js
  end

  test "u ulohy jen pro mladsi neni formular ani tlacitko" do
    solver = Sosna::Solver.create!(name: 'Eva', last_name: 'Velká', annual: '99', email: 'eva@x.cz',
                                   where_to_send: 'school', grade_num: '9')
    jr = Sosna::Problem.create!(annual: 99, level: 'jr', round: 1, problem_no: 1, title: 'Myška')
    login([:user, :org, :admin])
    get :user_index, params: { roc: '99', level: 'jr', se: '1', id: solver.id }
    assert_response :success

    assert_match(/úloha pouze pro mladší řešitele/, response.body)
    assert_select "form#edit_sosna_solution_#{solution_for(solver, jr).id}", 0
    assert_select 'button.solution-scan', 0
  end

  test "po terminu resitel nema formular ani tlacitko ani modal" do
    Sosna::Config.where(key: 'deadline1').update_all(value: (Date.today - 7).to_s)
    login([:user])
    get :user_index, params: { roc: '99', level: 'pi', se: '1' }
    assert_response :success

    assert_select 'form[id^=edit_sosna_solution]', 0
    assert_select 'button.solution-scan', 0
    assert_select '#solution-scan-modal', 0
  end

  test "admin po terminu ma tlacitko u formulare" do
    Sosna::Config.where(key: 'deadline1').update_all(value: (Date.today - 7).to_s)
    solver = login([:user, :org, :admin])
    get :user_index, params: { roc: '99', level: 'pi', se: '1' }
    assert_response :success

    form_id = "edit_sosna_solution_#{solution_for(solver, @p1).id}"
    assert_select "form##{form_id}", 1
    assert_select "button.solution-scan[data-form='##{form_id}']", 1
    assert_select '#solution-scan-modal', 1
  end
end
