require 'test_helper'

class SosnaPaperLevelTest < ActiveSupport::TestCase
  def make(email, jr:, pi:)
    Sosna::Solver.create!(name: 'J', last_name: 'N', annual: '33', email: email,
                          where_to_send: 'home', street: 'X', num: '1', city: 'P',
                          psc: '100 00', grade_num: '5', paper_jr: jr, paper_pi: pi)
  end

  test "paper_level_where splits into disjoint piles" do
    jen_jr = make('jr@x.cz',  jr: true,  pi: false)
    jen_pi = make('pi@x.cz',  jr: false, pi: true)
    oba    = make('oba@x.cz', jr: true,  pi: true)

    najdi = ->(level) { Sosna::Solver.where(annual: '33')
                                     .where(Sosna::Solver.paper_level_where(level)).to_a }

    assert_equal [jen_jr],                 najdi.call('jr_only')
    assert_equal [jen_pi],                 najdi.call('pi_only')
    assert_equal [oba],                    najdi.call('both')
    assert_equal [jen_jr, jen_pi, oba].sort_by(&:id), najdi.call('').sort_by(&:id)
    # inclusive varianty (kompatibilita URL)
    assert_equal [jen_jr, oba].sort_by(&:id), najdi.call('jr').sort_by(&:id)
    assert_equal [jen_pi, oba].sort_by(&:id), najdi.call('pi').sort_by(&:id)
  end
end
