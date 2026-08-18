require 'test_helper'
require 'rake'

class SosnaBackfillPaperTest < ActiveSupport::TestCase
  setup do
    Tep::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['sosna:backfill_paper_levels'].reenable
  end

  def make_solver(email, where_to_send:, grade_num:, paper_jr: false, paper_pi: false)
    Sosna::Solver.create!(name: 'Jan', last_name: 'N', annual: '33', email: email,
                          where_to_send: where_to_send, grade_num: grade_num,
                          street: 'X', num: '1', city: 'Praha', psc: '100 00',
                          paper_jr: paper_jr, paper_pi: paper_pi)
  end

  test "backfill keeps current reality for paper solvers only" do
    junior  = make_solver('jr@x.cz',   where_to_send: 'home',   grade_num: '5')
    senior  = make_solver('pi@x.cz',   where_to_send: 'school', grade_num: '8')
    mailový = make_solver('mail@x.cz', where_to_send: 'email',  grade_num: '5')
    hotový  = make_solver('set@x.cz',  where_to_send: 'home',   grade_num: '5', paper_pi: true)

    Rake::Task['sosna:backfill_paper_levels'].invoke

    assert_equal [true, true],   [junior.reload.paper_jr, junior.paper_pi], 'junior dostával oba'
    assert_equal [false, true],  [senior.reload.paper_jr, senior.paper_pi], 'starší jen senior'
    assert_equal [false, false], [mailový.reload.paper_jr, mailový.paper_pi], 'mailoví se nedoplňují'
    assert_equal [false, true],  [hotový.reload.paper_jr, hotový.paper_pi], 'už nastavené se nepřepisuje'
  end
end
