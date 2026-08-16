require 'test_helper'
require 'tmpdir'

##
# Testy struktury uploads adresáře: soubory řešení se ukládají do
# var/uploads/rocnikNN[-jr]/serieMM/ a všechny download/zip/upload cesty
# fungují transparentně (DB drží cestu relativní k uploads).
class SosnaSolutionFilesTest < ActionController::TestCase
  tests Sosna::SolutionController
  include Devise::Test::ControllerHelpers

  UPLOADS = Sosna::SolutionController::UPLOAD_DIR
  raise 'testy musi bezet nad izolovanym uploads adresarem!' if UPLOADS == 'var/uploads/'

  setup do
    FileUtils.mkdir_p UPLOADS
    # download_rev je v ability.rb povolen jen roli :user (resitel),
    # org ma download/download_org -- proto admin potrebuje i :user
    @admin = User.new(email: 'admin@x.cz', password: 'password123', roles: [:user, :org, :admin])
    @admin.skip_confirmation!
    @admin.save!
    sign_in @admin

    @problem = Sosna::Problem.create!(annual: 99, level: 'pi', round: 1, problem_no: 1)
    @solver = Sosna::Solver.create!(name: 'Jan', last_name: 'Novák', annual: '99',
                                    email: 'jan@x.cz', where_to_send: 'school',
                                    grade_num: '9')
    @solution = Sosna::Solution.create!(problem: @problem, solver: @solver)
  end

  teardown do
    FileUtils.rm_rf UPLOADS + 'rocnik99'
    FileUtils.rm_rf UPLOADS + 'rocnik99-jr'
    FileUtils.rm_rf UPLOADS + 'tmp'
    Dir.glob(UPLOADS + 'reseni-roc99*').each { |f| File.delete f }
  end

  def pdf_upload
    path = File.join(Dir.mktmpdir, 'reseni.pdf')
    Prawn::Document.generate(path) { |pdf| pdf.text 'test' }
    Rack::Test::UploadedFile.new(path, 'application/pdf')
  end

  ### subdir v modelu

  test "subdir se sklada z rocniku a serie, junior ma priponu" do
    assert_equal 'rocnik99/serie01', @solution.subdir
    assert_equal 'rocnik40-jr/serie03', Sosna::Solution.subdir_for(40, 'jr', 3)
    assert_equal 'rocnik07/serie09', Sosna::Solution.subdir_for(7, 'pi', 9)
  end

  ### upload

  test "upload ulozi soubor do podadresare a do DB da relativni cestu" do
    patch :upload, params: { sosna_solution: { id: @solution.id, solution_file: pdf_upload } }
    @solution.reload
    assert_equal "rocnik99/serie01/#{@solution.get_filename_ori}", @solution.filename
    assert File.exist?(UPLOADS + @solution.filename), 'soubor lezi v podadresari'
    assert File.exist?(UPLOADS + @solution.filename + '.tmpl'), 'tmpl sidecar vedle nej'
  end

  test "upload juniorskeho reseni jde do rocnik99-jr" do
    problem_jr = Sosna::Problem.create!(annual: 99, level: 'jr', round: 1, problem_no: 1)
    junior = Sosna::Solver.create!(name: 'Mal', last_name: 'Ý', annual: '99',
                                   email: 'mal@x.cz', where_to_send: 'school',
                                   grade_num: '5')
    solution = Sosna::Solution.create!(problem: problem_jr, solver: junior)
    patch :upload, params: { sosna_solution: { id: solution.id, solution_file: pdf_upload } }
    solution.reload
    assert_match %r{^rocnik99-jr/serie01/}, solution.filename
    assert File.exist?(UPLOADS + solution.filename)
  end

  ### download

  test "download posle soubor podle cesty ulozene v DB" do
    dir = UPLOADS + 'rocnik99/serie01'
    FileUtils.mkdir_p dir
    fname = "rocnik99/serie01/#{@solution.get_filename_ori}"
    File.write(UPLOADS + fname, '%PDF-fake')
    @solution.update!(filename: fname, filename_orig: 'moje.pdf')

    get :download, params: { id: @solution.id }
    assert_response :success
    assert_equal '%PDF-fake', response.body
  end

  test "download_rev posle opravu podle cesty ulozene v DB" do
    dir = UPLOADS + 'rocnik99/serie01'
    FileUtils.mkdir_p dir
    fname = "rocnik99/serie01/#{@solution.get_filename_rev}"
    File.write(UPLOADS + fname, '%PDF-rev')
    @solution.update!(filename_corr: fname, filename_corr_display: 'moje-opraveno.pdf')

    get :download_rev, params: { id: @solution.id }
    assert_response :success
    assert_equal '%PDF-rev', response.body
  end

  ### zip download

  test "downall zabali reseni z podadresaru do zipu" do
    dir = UPLOADS + 'rocnik99/serie01'
    FileUtils.mkdir_p dir
    fname = "rocnik99/serie01/#{@solution.get_filename_ori}"
    File.write(UPLOADS + fname, '%PDF-fake')
    @solution.update!(filename: fname)

    get :downall, params: { roc: '99', level: 'pi', se: '1' }
    assert_response :success
    Tempfile.create(['test', '.zip']) do |t|
      t.binmode
      t.write response.body
      t.flush
      entries = []
      Zip::File.open(t.path) { |z| entries = z.map(&:name) }
      assert_includes entries, 'reseni/' + @solution.get_filename_ori
    end
  end

  test "downall tvori zip v uploads/tmp a uklizi stare zipy" do
    FileUtils.mkdir_p UPLOADS + 'tmp'
    old_zip = UPLOADS + 'tmp/solution-stary.zip'
    File.write(old_zip, 'x')
    File.utime(Time.now - 2 * 86400, Time.now - 2 * 86400, old_zip)

    get :downall, params: { roc: '99', level: 'pi', se: '1' }
    assert_response :success
    assert !File.exist?(old_zip), 'zip z minula uklizen'
    assert_empty Dir.glob(UPLOADS + '*.zip'), 'v koreni uploads zadny zip'
    assert !Dir.glob(UPLOADS + 'tmp/solution*.zip').empty?, 'novy zip vznikl v tmp/'
  end

  ### upload opravy

  test "upload_rev2 ulozi opravu do podadresare" do
    post :upload_rev2, params: { id: @solution.id, file_rev: pdf_upload }
    assert_response :no_content
    @solution.reload
    assert_equal "rocnik99/serie01/#{@solution.get_filename_rev}", @solution.filename_corr
    assert File.exist?(UPLOADS + @solution.filename_corr)
  end
end
