require 'test_helper'
require 'rake'

class ActBirthCheckTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('act:birth_check')
    Rake::Task['act:birth_check'].reenable
  end

  def make(email, birth_par, birth_solver)
    u = User.new(email: email, password: 'password123'); u.skip_confirmation!; u.save!
    Sosna::Solver.new(user_id: u.id, name: 'A', last_name: 'B', birth: birth_solver).save!(validate: false)
    Act::Participant.create!(name: 'A', last_name: email, nickname: '', user_id: u.id, activated: 'desact', birth: birth_par, sex: 'male')
  end

  test "reports and fixes one-day shift" do
    shifted = make('a@x.cz', Time.utc(2013, 12, 31, 23), '1.1.2014')
    ok      = make('b@x.cz', Time.utc(2014, 2, 2), '2. 2. 2014')
    far     = make('c@x.cz', Time.utc(2014, 5, 5), '1.1.2014')
    out = capture_io { Rake::Task['act:birth_check'].invoke }.first
    assert_match "Posun o den proti řešiteli (1)", out
    assert_match "Jiný rozdíl – řeší člověk (1)", out
    assert_equal Time.utc(2013, 12, 31, 23), shifted.reload.birth

    Rake::Task['act:birth_check'].reenable
    ENV['FIX'] = '1'
    capture_io { Rake::Task['act:birth_check'].invoke }
    assert_equal Date.new(2014, 1, 1), shifted.reload.birth.utc.to_date
    assert_equal Time.utc(2014, 5, 5), far.reload.birth
    assert_equal Time.utc(2014, 2, 2), ok.reload.birth
  ensure
    ENV.delete('FIX')
  end
end
