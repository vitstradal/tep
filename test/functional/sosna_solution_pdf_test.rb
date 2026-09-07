require 'test_helper'
require 'rake'

class SosnaSolutionPdfTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Sosna::SolutionController

  UPLOADS = Sosna::SolutionController::UPLOAD_DIR

  setup do
    @org = User.new(email: 'org-pdf@x.cz', password: 'password123', roles: [:org])
    @org.skip_confirmation!
    @org.save!
    Sosna::Config.create!(key: 'annual', value: '40')
    @problem = Sosna::Problem.create!(annual: '40', round: 1, problem_no: 1)
    @solver = Sosna::Solver.create!(name: 'Jan', last_name: 'Kid', annual: '40',
                                    email: 'kid-pdf@x.cz', where_to_send: 'email')
    FileUtils.mkdir_p File.join(UPLOADS, 'rocnik40/serie01')
  end

  def make_solution(fname, obsah, gzip: false)
    rel = "rocnik40/serie01/#{fname}"
    full = File.join(UPLOADS, rel)
    if gzip
      Zlib::GzipWriter.open("#{full}.gz", 9) { |g| g.write obsah }
    else
      File.binwrite(full, obsah)
    end
    Sosna::Solution.create!(solver: @solver, problem: @problem,
                            filename: rel, filename_orig: fname)
  end

  test "download serves plain pdf as before" do
    s = make_solution('plain.pdf', '%PDF-plain')
    sign_in @org
    get :download, params: { id: s.id }
    assert_response :success
    assert_equal '%PDF-plain', response.body
    assert_equal 'application/pdf', response.media_type
  end

  test "download transparently decompresses gzipped pdf" do
    s = make_solution('komprim.pdf', '%PDF-gzipnuty obsah', gzip: true)
    sign_in @org
    get :download, params: { id: s.id }
    assert_response :success
    assert_equal '%PDF-gzipnuty obsah', response.body
    assert_equal 'application/pdf', response.media_type
  end

  test "compress_pdfs rake task compresses and keeps incompressible" do
    Tep::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['sosna:compress_pdfs'].reenable
    dobre = File.join(UPLOADS, 'rocnik40/serie01/dobre.pdf')
    spatne = File.join(UPLOADS, 'rocnik40/serie01/spatne.pdf')
    File.binwrite(dobre, 'A' * 100_000)                     # krásně stlačitelné
    File.binwrite(spatne, Random.bytes(100_000))            # nestlačitelné
    capture_io { Rake::Task['sosna:compress_pdfs'].invoke('40') }

    assert File.exist?("#{dobre}.gz"), 'stlačitelný soubor má .gz'
    assert_not File.exist?(dobre),     'originál stlačitelného je pryč'
    assert File.exist?(spatne),        'nestlačitelný zůstává originálem'
    assert_not File.exist?("#{spatne}.gz")
    # a obsah jde zpět beze změny
    assert_equal 'A' * 100_000, Sosna::Solution.read_pdf(UPLOADS, 'rocnik40/serie01/dobre.pdf')
  end

  teardown do
    FileUtils.rm_rf File.join(UPLOADS, 'rocnik40')
  end
end
