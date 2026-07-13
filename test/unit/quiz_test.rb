require 'test_helper'

class QuizTest < ActiveSupport::TestCase
  test "name must be unique" do
    Quiz.create!(name: 'advent-2026', quiz_type: 'advent')
    assert_not Quiz.new(name: 'advent-2026').valid?
  end

  test "open? respects window" do
    q = Quiz.new(name: 'q', opens_on: Date.new(2026, 12, 1), closes_on: Date.new(2026, 12, 24))
    assert_not q.open?(Date.new(2026, 11, 30))
    assert q.open?(Date.new(2026, 12, 1))
    assert q.open?(Date.new(2026, 12, 24))
    assert_not q.open?(Date.new(2026, 12, 25))
  end

  test "open? without window is always open" do
    assert Quiz.new(name: 'q').open?
  end

  test "advent question opens day by day" do
    q = Quiz.new(name: 'a', quiz_type: 'advent', opens_on: Date.new(2026, 12, 1), closes_on: Date.new(2026, 12, 31))
    assert q.question_open?(1, Date.new(2026, 12, 1))
    assert_not q.question_open?(2, Date.new(2026, 12, 1))
    assert q.question_open?(24, Date.new(2026, 12, 24))
  end

  test "non-advent question needs only open window" do
    q = Quiz.new(name: 'k', quiz_type: 'quiz')
    assert q.question_open?(5)
  end

  test "one answer per quiz, question and friend" do
    q = Quiz.create!(name: 'k')
    f = Friend.create!(nick: 'Petr')
    QuizAnswer.create!(quiz: q, friend: f, question_no: 1, answer: '42')
    dup = QuizAnswer.new(quiz: q, friend: f, question_no: 1, answer: '43')
    assert_not dup.valid?
  end
end
