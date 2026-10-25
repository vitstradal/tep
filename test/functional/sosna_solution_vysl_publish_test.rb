require 'test_helper'
require 'tmpdir'

class SosnaSolutionVyslPublishTest < ActionController::TestCase
  tests Sosna::SolutionController
  include Devise::Test::ControllerHelpers

  setup do
    @dir = Dir.mktmpdir
    Rugged::Repository.init_at(@dir, :bare)
    @orig = Giwi.giwis[:web_edit]
    @giwi = Giwi.giwis[:web_edit] = Giwi.new(:web_edit, { path: @dir, ext: '.wiki', read: :org, update: :morg })
    @giwi.set_files({ 'archiv/index.wiki' => "{{archiv  99|zr}}\n" }, 'init', 'x <x@x.cz>')

    @admin = User.new(email: 'admin@x.cz', password: 'password123', roles: [:user, :org, :morg, :admin])
    @admin.skip_confirmation!
    @admin.save!
    sign_in @admin

    problem = Sosna::Problem.create!(annual: 99, level: 'pi', round: 1, problem_no: 1)
    solver = Sosna::Solver.create!(name: 'Jan', last_name: 'Novák', annual: '99', email: 'jan@x.cz',
                                   where_to_send: 'school', grade_num: '9')
    Sosna::Solution.create!(problem: problem, solver: solver, score: 5)
  end

  teardown do
    Giwi.giwis[:web_edit] = @orig
    FileUtils.rm_rf @dir
  end

  test "publishes results page and sets the v flag" do
    post :update_results, params: { roc: '99', level: 'pi', se: '1' }
    post :vysl_publish, params: { roc: '99', level: 'pi', se: '1' }
    assert_response :redirect
    page, = @giwi.get_page('archiv/rocnik99/vysl1.wiki')
    assert_match(/Výsledková listina po 1\. sérii 99\. ročníku/, page)
    assert_match(/Novák/, page)
    assert_equal "{{archiv  99|zrv}}\n", @giwi.get_page('archiv/index.wiki').first
  end
end
