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

  test "export lists only undecided rows, import applies automatic and edited proposals only with APPLY" do
    shifted  = make('a@x.cz', Time.utc(2013, 12, 31, 23), '1.1.2014')
    ok       = make('b@x.cz', Time.utc(2014, 2, 2), '2. 2. 2014')
    tz       = make('c@x.cz', Time.utc(2014, 5, 4, 22), nil)
    tzsolv   = make('d@x.cz', Time.utc(2009, 6, 18, 22), '12.6.2009')
    badyear  = make('e@x.cz', Time.utc(16, 2, 11), '11.2.2016')
    kidyear  = make('f@x.cz', Time.utc(2022, 2, 20, 23), '21.2.2012')
    solvyear = make('g@x.cz', Time.utc(2008, 11, 23, 23), '24.11.2024')
    plusone  = make('h@x.cz', Time.utc(2018, 4, 28), %w[29.4.2018 19.3.2020])
    swapped  = make('i@x.cz', Time.utc(2014, 9, 8), '9.8.2014')
    other    = make('j@x.cz', Time.utc(2013, 12, 1), '19.2.2013')
    capture_io { Rake::Task['act:birth_export'].invoke }
    rows = CSV.read(@file, headers: true)
    assert_equal [tzsolv.id, other.id].sort, rows.map { |r| r['id'].to_i }.sort
    row = rows.find { |r| r['id'].to_i == tzsolv.id }
    assert_equal '19.6.2009', row['navrh']
    assert_equal '18.6.2009', row['zobrazuje']

    csv = CSV.read(@file)
    csv.each { |r| r[7] = '12.6.2009' if r[0] == tzsolv.id.to_s }
    csv.each { |r| r[7] = '' if r[0] == other.id.to_s }
    File.write(@file, csv.map(&:to_csv).join)

    out = capture_io { Rake::Task['act:birth_import'].invoke }.first
    assert_match '8 změn', out
    assert_equal Time.utc(2013, 12, 31, 23), shifted.reload.birth

    Rake::Task['act:birth_import'].reenable
    ENV['APPLY'] = '1'
    capture_io { Rake::Task['act:birth_import'].invoke }
    { shifted => [2014, 1, 1], ok => [2014, 2, 2], tz => [2014, 5, 5], tzsolv => [2009, 6, 12], badyear => [2016, 2, 11],
      kidyear => [2012, 2, 21], solvyear => [2008, 11, 24], plusone => [2018, 4, 29], swapped => [2014, 8, 9],
      other => [2013, 12, 1] }.each { |par, ymd| assert_equal Time.utc(*ymd), par.reload.birth, par.email }
  end
end
