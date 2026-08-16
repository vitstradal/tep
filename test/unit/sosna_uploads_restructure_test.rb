require 'test_helper'
require 'rake'

##
# Test konverzního tasku sosna:uploads_restructure — přesun plochých
# var/uploads/ souborů do rocnikNN[-jr]/serieMM/ + update cest v DB.
class SosnaUploadsRestructureTest < ActiveSupport::TestCase
  UPLOADS = Sosna::SolutionController::UPLOAD_DIR

  setup do
    FileUtils.mkdir_p UPLOADS
    Tep::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['sosna:uploads_restructure'].reenable

    @problem = Sosna::Problem.create!(annual: 99, level: 'pi', round: 2, problem_no: 1)
    @solver = Sosna::Solver.create!(name: 'Jan', last_name: 'Novák', annual: '99',
                                    email: 'jan@x.cz', where_to_send: 'school')
    @solution = Sosna::Solution.create!(problem: @problem, solver: @solver)
  end

  teardown do
    FileUtils.rm_rf UPLOADS + 'rocnik99'
    FileUtils.rm_rf UPLOADS + 'rocnik99-jr'
    Dir.glob(UPLOADS + 'reseni-roc99*').each { |f| File.delete f }
  end

  def run_task
    Rake::Task['sosna:uploads_restructure'].reenable
    out, _ = capture_io { Rake::Task['sosna:uploads_restructure'].invoke }
    out
  end

  test "presune soubor i tmpl do podadresare a updatne DB" do
    fname = @solution.get_filename_ori
    File.write(UPLOADS + fname, '%PDF-ori')
    File.write(UPLOADS + fname + '.tmpl', '%PDF-tmpl')
    @solution.update!(filename: fname)

    out = run_task

    @solution.reload
    target = "rocnik99/serie02/#{fname}"
    assert_equal target, @solution.filename
    assert File.exist?(UPLOADS + target), 'soubor presunut'
    assert File.exist?(UPLOADS + target + '.tmpl'), 'tmpl presunut'
    assert !File.exist?(UPLOADS + fname), 'original zmizel'
    assert_match 'přesunuto 1', out
  end

  test "presune i opravu (filename_corr)" do
    fname = @solution.get_filename_rev
    File.write(UPLOADS + fname, '%PDF-rev')
    @solution.update!(filename_corr: fname)

    run_task

    assert_equal "rocnik99/serie02/#{fname}", @solution.reload.filename_corr
    assert File.exist?(UPLOADS + "rocnik99/serie02/#{fname}")
  end

  test "je idempotentni - druhy beh nic nemeni" do
    fname = @solution.get_filename_ori
    File.write(UPLOADS + fname, '%PDF-ori')
    @solution.update!(filename: fname)

    run_task
    first = @solution.reload.filename
    out = run_task

    assert_equal first, @solution.reload.filename
    assert_match 'přesunuto 0', out
    assert_match 'už převedeno 1', out
  end

  test "chybejici soubor nechava DB beze zmeny" do
    fname = @solution.get_filename_ori
    @solution.update!(filename: fname)   # soubor neexistuje

    out = run_task

    assert_equal fname, @solution.reload.filename
    assert_match 'CHYBÍ', out
    assert_match 'chybí 1', out
  end

  test "DRY=1 nic nepresune ani neupdatne" do
    fname = @solution.get_filename_ori
    File.write(UPLOADS + fname, '%PDF-ori')
    @solution.update!(filename: fname)

    ENV['DRY'] = '1'
    begin
      run_task
    ensure
      ENV.delete 'DRY'
    end

    assert_equal fname, @solution.reload.filename
    assert File.exist?(UPLOADS + fname), 'soubor zustal na miste'
  end
end
