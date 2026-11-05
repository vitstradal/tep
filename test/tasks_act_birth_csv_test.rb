require 'test_helper'
require 'rake'
require 'csv'

class ActBirthCsvTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('act:birth_export')
    %w[act:birth_export act:birth_import].each { |t| Rake::Task[t].reenable }
    @file = Rails.root.join('tmp', "birth-test-#{Process.pid}.csv").to_s
    ENV['FILE'] = @file
  end

  teardown do
    File.delete(@file) if File.exist?(@file)
    %w[FILE APPLY].each { |k| ENV.delete(k) }
  end

  def make(email, birth_par, birth_solver)
    u = User.new(email: email, password: 'password123'); u.skip_confirmation!; u.save!
    Array(birth_solver).each { |b| Sosna::Solver.new(user_id: u.id, name: 'A', last_name: 'B', birth: b).save!(validate: false) }
    Act::Participant.create!(name: 'A', last_name: email, nickname: '', user_id: u.id, activated: 'desact', birth: birth_par, sex: 'male')
  end

  test "export proposes, edited csv is applied only with APPLY" do
    shifted = make('a@x.cz', Time.utc(2013, 12, 31, 23), '1.1.2014')
    ok      = make('b@x.cz', Time.utc(2014, 2, 2), '2. 2. 2014')
    tz      = make('c@x.cz', Time.utc(2014, 5, 4, 22), nil)
    tzsolv  = make('d@x.cz', Time.utc(2009, 6, 18, 22), '12.6.2009')
    badyear = make('e@x.cz', Time.utc(16, 2, 11), '11.2.2016')
    kidyear = make('f@x.cz', Time.utc(2022, 2, 20, 23), '21.2.2012')
    solvyear = make('g@x.cz', Time.utc(2008, 11, 23, 23), '24.11.2024')
    plusone = make('h@x.cz', Time.utc(2018, 4, 28), %w[29.4.2018 19.3.2020])
    swapped = make('i@x.cz', Time.utc(2014, 9, 8), '9.8.2014')
    capture_io { Rake::Task['act:birth_export'].invoke }
    rows = CSV.read(@file, col_sep: ';', headers: true).to_h { |r| [r['id'].to_i, r] }
    assert_equal '21.2.2012', rows[kidyear.id]['navrh']
    assert_equal '24.11.2008', rows[solvyear.id]['navrh']
    assert_equal '29.4.2018', rows[plusone.id]['navrh']
    assert_equal '9.8.2014', rows[swapped.id]['navrh']
    assert_equal '1.1.2014', rows[shifted.id]['navrh']
    assert_equal '31.12.2013', rows[shifted.id]['zobrazuje']
    assert_equal '2.2.2014', rows[ok.id]['navrh']
    assert_equal '5.5.2014', rows[tz.id]['navrh']
    assert_equal '19.6.2009', rows[tzsolv.id]['navrh']
    assert_match(/\AROZHODNI/, rows[tzsolv.id]['duvod'])
    assert_equal '11.2.2016', rows[badyear.id]['navrh']
    assert_equal tzsolv.id.to_s, CSV.read(@file, col_sep: ';')[1][0]

    csv = CSV.read(@file, col_sep: ';')
    csv.each { |r| r[7] = '6.6.2014' if r[0] == tz.id.to_s }
    File.write(@file, csv.map { |r| r.to_csv(col_sep: ';') }.join)

    out = capture_io { Rake::Task['act:birth_import'].invoke }.first
    assert_match '8 změn', out
    assert_equal Time.utc(2013, 12, 31, 23), shifted.reload.birth

    Rake::Task['act:birth_import'].reenable
    ENV['APPLY'] = '1'
    capture_io { Rake::Task['act:birth_import'].invoke }
    assert_equal Time.utc(2014, 1, 1), shifted.reload.birth
    assert_equal Time.utc(2014, 6, 6), tz.reload.birth
    assert_equal Time.utc(2014, 2, 2), ok.reload.birth
  end
end
