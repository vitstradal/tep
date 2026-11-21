require 'test_helper'
require 'adventomat'

class AdventomatTest < ActiveSupport::TestCase
  PRAGUE = ActiveSupport::TimeZone['Europe/Prague']

  def page(extra_header = '', days = (1..24))
    body = days.map { |n| "== #{n} ==\nKolik je **#{n}** + 12?\nvýsledek: #{n + 12}\npoznámka: tajné #{n}\n" }.join("\n")
    "= Adventomat 2026 =\n\nPoznámka pro orgy.\n#{extra_header}\n#{body}\n== bonus ==\nBonus?\n[[Image(b.png)]]\nvýsledek: 1 187\n\n" \
      "== odměna ==\nGratulace!\n[[Image(/adventomat/2026/odmena.png)]]\n"
  end

  test "header defaults and parsed days" do
    a = Adventomat.parse(2026, page)
    assert_equal 'advent-2026', a.quiz_name
    assert_equal 2026, Adventomat.year_of('advent-2026')
    assert_nil Adventomat.year_of('kviz-2026')
    assert_equal (1..25).to_a, a.days.keys.sort
    assert_equal 13, a.days[1].result
    assert_equal 1187, a.days[25].result
    assert_equal 'bonus', a.days[25].label
    assert_equal 4, a.min_table
    assert_equal PRAGUE.local(2026, 12, 26, 23, 59), a.closes_at
    assert_equal ['b.png'], a.days[25].images
    assert_equal ['odmena.png'], a.reward_images
  end

  test "header overrides" do
    a = Adventomat.parse(2025, page("otevírání: 0:42\nuzávěrka: 2. 1. 2026 12:00\nv tabulce od: 6\npořadí: 3, bonus, 1\n"))
    assert_equal PRAGUE.local(2025, 12, 1, 0, 42), a.open_at(1)
    assert_equal PRAGUE.local(2026, 1, 2, 12, 0), a.closes_at
    assert_equal 6, a.min_table
    assert_equal [3, 25, 1], a.order.first(3)
    assert_equal (1..25).to_a, a.order.sort
  end

  test "default order is shuffled but stable per year" do
    a = Adventomat.parse(2026, page)
    assert_equal (1..25).to_a, a.order.sort
    refute_equal (1..25).to_a, a.order
    assert_equal a.order, Adventomat.parse(2026, page).order
  end

  test "opening time may have seconds" do
    a = Adventomat.parse(2026, "otevírání: 3:14:15\n\n== 1 ==\nA\nvýsledek: 1\n")
    assert_empty a.header_errors
    assert_equal PRAGUE.local(2026, 12, 1, 3, 14, 15), a.open_at(1)
    assert_not a.open?(1, PRAGUE.local(2026, 12, 1, 3, 14, 14))
    assert a.open?(1, PRAGUE.local(2026, 12, 1, 3, 14, 15))
  end

  test "opening at 3:14 Prague, bonus with day 24" do
    a = Adventomat.parse(2026, page)
    refute a.open?(1, PRAGUE.local(2026, 12, 1, 3, 13, 59))
    assert a.open?(1, PRAGUE.local(2026, 12, 1, 3, 14))
    refute a.open?(2, PRAGUE.local(2026, 12, 1, 3, 14))
    assert_equal a.open_at(24), a.open_at(25)
    assert_equal PRAGUE.local(2026, 12, 2, 3, 14), a.next_open_at(PRAGUE.local(2026, 12, 1, 12))
    assert_nil a.next_open_at(PRAGUE.local(2026, 12, 25))
    assert a.open?(5, PRAGUE.local(2027, 6, 1))
  end

  test "rendered day hides result and note and tunnels images" do
    a = Adventomat.parse(2026, page)
    html = a.day_html(25)
    assert_match 'Bonus?', html
    assert_match 'src="/quiz/advent-2026/obrazek/b.png"', html
    assert_no_match(/1 187|výsledek|tajné/, html)
    assert_match '<strong>5</strong>', a.day_html(5)
    assert_match 'src="/quiz/advent-2026/obrazek/odmena.png"', a.reward_html
  end

  test "answers are numbers, spaces ignored" do
    a = Adventomat.parse(2026, page)
    assert_equal true, a.check_answer(25, ' 1 187 ')
    assert_equal false, a.check_answer(25, '1188')
    assert_equal :not_number, a.check_answer(1, 'třináct')
    assert_equal :not_number, a.check_answer(1, '')
    assert_equal true, a.check_answer(1, '13')
  end

  test "issues report missing day, bad result and missing image" do
    text = page('', (1..23)).sub("výsledek: 15\n", "výsledek: patnáct\n")
    a = Adventomat.parse(2026, text, files: ['odmena.png'])
    texts = a.issues.map { |i| [i[:day], i[:level], i[:text]] }
    assert_includes texts, [24, :error, 'den chybí']
    assert_includes texts, [3, :error, 'výsledek není celé číslo']
    assert_includes texts, [25, :error, 'obrázek b.png v piki není']
    assert_empty Adventomat.parse(2026, page, files: %w[b.png odmena.png]).issues
  end
end
