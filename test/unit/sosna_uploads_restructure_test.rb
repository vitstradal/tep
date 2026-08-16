require 'test_helper'
require 'rake'

##
# Test konverzního tasku sosna:uploads_restructure — přesun plochých
# var/uploads/ souborů do rocnikNN[-jr]/serieMM/ + update cest v DB.
class SosnaUploadsRestructureTest < ActiveSupport::TestCase
  UPLOADS = Sosna::SolutionController::UPLOAD_DIR
  raise 'testy musi bezet nad izolovanym uploads adresarem!' if UPLOADS == 'var/uploads/'

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

  ### oprava sirotku (problem smazan a znovu zalozen)

  # vyrobi reseni, jehoz uloha byla smazana; roc/se/ul zustavaji ve jmene souboru
  def make_orphan(problem_no: 3, with_file: true)
    p_old = Sosna::Problem.create!(annual: 99, level: 'pi', round: 2, problem_no: problem_no)
    sol = Sosna::Solution.create!(problem: p_old, solver: @solver)
    fname = sol.get_filename_ori
    File.write(UPLOADS + fname, '%PDF-orphan') if with_file
    sol.update!(filename: fname)
    p_old.delete
    [sol, fname]
  end

  test "sirotek bez dvojnika se prepoji na znovuzalozenou ulohu" do
    sol, fname = make_orphan
    p_new = Sosna::Problem.create!(annual: 99, level: 'pi', round: 2, problem_no: 3)

    out = run_task

    assert_equal p_new.id, sol.reload.problem_id
    assert_equal "rocnik99/serie02/#{fname}", sol.filename, 'soubor se presune v temze behu'
    assert File.exist?(UPLOADS + sol.filename)
    assert_match 'repoint 1', out
  end

  test "sirotkuv soubor prevezme dvojnik bez souboru, sirotek se smaze" do
    sol, fname = make_orphan
    p_new = Sosna::Problem.create!(annual: 99, level: 'pi', round: 2, problem_no: 3)
    twin = Sosna::Solution.create!(problem: p_new, solver: @solver)

    out = run_task

    assert_nil Sosna::Solution.find_by(id: sol.id), 'sirotek smazan'
    assert_equal "rocnik99/serie02/#{fname}", twin.reload.filename
    assert File.exist?(UPLOADS + twin.filename)
    assert_match 'adopt 1', out
  end

  test "sirotek-duplikat se smaze, dvojnikuv soubor zustava" do
    sol, fname = make_orphan(with_file: false)
    p_new = Sosna::Problem.create!(annual: 99, level: 'pi', round: 2, problem_no: 3)
    File.write(UPLOADS + fname, '%PDF-twin')
    twin = Sosna::Solution.create!(problem: p_new, solver: @solver)
    twin.update!(filename: fname)

    out = run_task

    assert_nil Sosna::Solution.find_by(id: sol.id)
    assert_equal '%PDF-twin', File.read(UPLOADS + twin.reload.filename)
    assert_match 'dup 1', out
  end

  ### CLEAN=1 uklid korene

  test "CLEAN smaze stare nereferencovane a necha mlade" do
    old_junk = UPLOADS + 'reseni-roc98pi-se01-ul1-rel999-ori-Mrtvy-Soubor.pdf'
    File.write(old_junk, 'x')
    File.utime(Time.now - 60 * 86400, Time.now - 60 * 86400, old_junk)
    young_junk = UPLOADS + 'reseni-roc98pi-se01-ul2-rel999-ori-Cerstvy-Soubor.pdf'
    File.write(young_junk, 'x')

    ENV['CLEAN'] = '1'
    begin
      out = run_task
    ensure
      ENV.delete 'CLEAN'
    end

    assert !File.exist?(old_junk), 'stary nereferencovany smazan'
    assert File.exist?(young_junk), 'mladsi nez 30 dni zustava'
    assert_match 'smazáno 1', out
  ensure
    [young_junk, old_junk].each { |f| File.delete(f) if f && File.exist?(f) }
  end

  test "navratky se presunou z korene do navratky/" do
    confirm = UPLOADS + 'confirm-file-12345.pdf'
    File.write(confirm, '%PDF-navratka')

    out = run_task

    assert !File.exist?(confirm), 'v koreni uz neni'
    assert_equal '%PDF-navratka', File.read(UPLOADS + 'navratky/confirm-file-12345.pdf')
    assert_match 'navratek 1', out
  ensure
    f = UPLOADS + 'navratky/confirm-file-12345.pdf'
    File.delete(f) if File.exist?(f)
    File.delete(confirm) if confirm && File.exist?(confirm)
  end

  test "bez CLEAN se nereferencovane soubory nemazou" do
    junk = UPLOADS + 'reseni-roc98pi-se01-ul3-rel999-ori-Stary-Soubor.pdf'
    File.write(junk, 'x')
    File.utime(Time.now - 60 * 86400, Time.now - 60 * 86400, junk)

    run_task

    assert File.exist?(junk)
  ensure
    File.delete(junk) if File.exist?(junk)
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
