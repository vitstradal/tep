##
# Sčítací captcha registrace přítele: příklad je v HTML rozházený (pořadí číslic
# řídí CSS, mezi nimi neviditelné návnady), součet zná jen session.
class FriendCaptcha
  MIN_AGE = 3.seconds
  MAX_AGE = 30.minutes
  ZW = ["​", "‌", "⁠"].freeze
  HIDE = ['display:none', 'position:absolute;left:-9999px', 'font-size:0;opacity:0'].freeze

  attr_reader :sum, :html

  def initialize(random: Random.new)
    @rnd = random
    a = @rnd.rand(11..79)
    b = @rnd.rand(3..(99 - a))
    @sum = a + b
    @html = %(<span class="fc">#{_number(a)}<span class="fc-op"></span>#{_number(b)}</span>)
  end

  def state
    { 'sum' => @sum, 'at' => Time.current.to_i }
  end

  def self.valid?(state, answer, now: Time.current)
    return false unless state.is_a?(Hash) && answer.to_s.strip.match?(/\A\d{1,3}\z/)
    age = now.to_i - state['at'].to_i
    age.between?(MIN_AGE.to_i, MAX_AGE.to_i) && answer.to_i == state['sum']
  end

  private

  def _number(n)
    digits = n.to_s.chars.each_with_index.map { |d, i| %(<span style="order:#{i * 2 + 1}">#{d}#{ZW.sample(random: @rnd)}</span>) }
    decoys = Array.new(@rnd.rand(2..3)) { %(<span style="order:#{@rnd.rand(0..9)};#{HIDE.sample(random: @rnd)}">#{@rnd.rand(0..9)}</span>) }
    %(<span class="fc-n">#{(digits + decoys).shuffle(random: @rnd).join}</span>)
  end
end
