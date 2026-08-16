require 'test_helper'
require 'rake'

class FriendsCleanupTest < ActiveSupport::TestCase
  setup do
    Tep::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['friends:cleanup'].reenable
  end

  test "deletes stale anonymous friends with answers" do
    stale = Friend.create!(nick: 'Stary', last_seen_at: 2.years.ago)
    fresh = Friend.create!(nick: 'Novy', last_seen_at: 1.day.ago)
    q = Quiz.create!(name: 'q')
    QuizAnswer.create!(quiz: q, friend: stale, question_no: 1, answer: 'x')
    out, _ = capture_io { Rake::Task['friends:cleanup'].invoke }
    assert_match 'mažu 1 anonymních', out
    assert_nil Friend.find_by(id: stale.id)
    assert Friend.find_by(id: fresh.id)
    assert_equal 0, QuizAnswer.where(friend_id: stale.id).count
  end

  test "deletes old unconfirmed users and unlinks friend" do
    u = User.new(email: 'stale@x.cz', password: SecureRandom.hex(16))
    u.skip_confirmation_notification!
    u.save!
    u.update_column(:confirmation_sent_at, 2.months.ago)
    f = Friend.create!(nick: 'P', user: u, last_seen_at: 1.day.ago)
    capture_io { Rake::Task['friends:cleanup'].invoke }
    assert_nil User.find_by(id: u.id)
    assert_nil f.reload.user_id, 'friend se vrací do anonymního stavu'
  end

  test "keeps unconfirmed user with solver" do
    u = User.new(email: 'sol@x.cz', password: SecureRandom.hex(16))
    u.skip_confirmation_notification!
    u.save!
    u.update_column(:confirmation_sent_at, 2.months.ago)
    Sosna::Solver.create!(name: 'J', last_name: 'N', annual: '33',
                          email: 'sol@x.cz', user_id: u.id, where_to_send: 'school')
    capture_io { Rake::Task['friends:cleanup'].invoke }
    assert User.find_by(id: u.id)
  end

  test "keeps fresh unconfirmed user" do
    u = User.new(email: 'cerstvy@x.cz', password: SecureRandom.hex(16))
    u.skip_confirmation_notification!
    u.save!
    capture_io { Rake::Task['friends:cleanup'].invoke }
    assert User.find_by(id: u.id)
  end
end
