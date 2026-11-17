require 'test_helper'
require 'minitest/mock'

class DeviceLoginTest < ActiveSupport::TestCase
  ANDROID_CHROME = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36'.freeze
  IPHONE_SAFARI = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1'.freeze
  WINDOWS_EDGE = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0'.freeze

  def make_user(email = 'dl@example.com')
    User.new(email: email, password: 'password123', roles: [:user]).tap { |u| u.skip_confirmation!; u.save! }
  end

  def create(token: 'tok', ip: '1.2.3.4', ua: ANDROID_CHROME)
    DeviceLogin.create_for!(token: token, user_agent: ua, ip: ip, return_to: '/x')
  end

  def stub_random(values, &block)
    seq = values.cycle
    SecureRandom.stub(:random_number, ->(_n) { seq.next }, &block)
  end

  test 'ikony' do
    assert_equal 22, DeviceLogin::ICONS.size
    assert_equal ['A', '🚗', 'auto'], DeviceLogin::ICONS.first
    assert_equal ['H', '🍄', 'houba'], DeviceLogin::ICONS[7]
    assert_equal ['R', '🚀', 'raketa'], DeviceLogin::ICONS[16]
    assert_equal ['Z', '🦓', 'zebra'], DeviceLogin::ICONS.last
    letters = DeviceLogin::ICONS.map(&:first)
    assert_equal letters.sort, letters
    assert_equal letters.uniq, letters
    assert_equal ('A'..'Z').to_a - %w[Q W X Y], letters
    DeviceLogin::ICONS.each do |letter, emoji, name|
      assert_equal letter, name[0].upcase, name
      assert emoji.present?
    end
    assert_equal 22, DeviceLogin::ICONS.map { |i| i[1] }.uniq.size
  end

  test 'random_code losuje z celého poolu' do
    seen = []
    code = SecureRandom.stub(:random_number, ->(n) { seen << n; 21 }) { DeviceLogin.random_code }
    assert_equal [22, 22, 22, 22], seen
    assert_equal '21-21-21-21', code
  end

  test 'create_for! vytvoří pending s kódem' do
    travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
      dl = create
      assert_equal 'pending', dl.state
      assert_match(/\A\d+-\d+-\d+-\d+\z/, dl.code)
      assert dl.code.split('-').map(&:to_i).all? { |i| (0..21).cover?(i) }
      assert_in_delta (Time.current + 5.minutes).to_f, dl.expires_at.to_f, 1
      assert_equal DeviceLogin.digest('tok'), dl.device_digest
      assert_equal 64, dl.device_digest.size
      assert_equal '1.2.3.4', dl.ip_bucket
      assert_equal '/x', dl.return_to
      assert_equal 4, dl.icons.size
      assert_equal dl.code.split('-').map { |i| DeviceLogin::ICONS[i.to_i] }, dl.icons
      assert_equal 300, dl.expires_in
    end
  end

  test 'kolize kódu vede na jiný kód, trvalá kolize na Busy' do
    first = stub_random([1, 2, 3, 4]) { create(token: 'a') }
    assert_equal '1-2-3-4', first.code
    second = stub_random([1, 2, 3, 4, 5, 6, 7, 8]) { create(token: 'b') }
    assert_equal '5-6-7-8', second.code
    assert_raises(DeviceLogin::Busy) { stub_random([1, 2, 3, 4]) { create(token: 'c') } }
  end

  def insert_pending(n, expires_at:, ip_bucket: 'x')
    now = Time.current
    rows = Array.new(n) do |i|
      { code: "0-0-#{i / DeviceLogin::ICONS.size}-#{i % DeviceLogin::ICONS.size}", state: 'pending', device_digest: "d#{i}", ip_bucket: ip_bucket,
        expires_at: expires_at, created_at: now, updated_at: now }
    end
    DeviceLogin.insert_all(rows)
  end

  test 'strop platných pending' do
    insert_pending(500, expires_at: 5.minutes.from_now)
    assert_raises(DeviceLogin::Busy) { create }
  end

  test 'vypršelé pending se do stropu nepočítají' do
    insert_pending(500, expires_at: 1.minute.ago)
    assert_equal 'pending', create.state
  end

  test 'limit na IP za hodinu' do
    travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
      30.times { |i| create(token: "t#{i}") }
      assert_raises(DeviceLogin::Busy) { create(token: 'navic') }
      assert_equal 'pending', create(token: 'jinde', ip: '1.2.3.5').state
    end
    travel_to Time.zone.local(2026, 11, 17, 13, 0, 1) do
      assert_equal 'pending', create(token: 'pozdeji').state
    end
  end

  test 'ip_bucket' do
    assert_equal '1.2.3.4', DeviceLogin.ip_bucket('1.2.3.4')
    assert_equal '2001:db8:1:2::/64', DeviceLogin.ip_bucket('2001:db8:1:2::5')
    assert_equal DeviceLogin.ip_bucket('2001:db8:1:2::5'), DeviceLogin.ip_bucket('2001:db8:1:2::9')
    assert_not_equal DeviceLogin.ip_bucket('2001:db8:1:2::5'), DeviceLogin.ip_bucket('2001:db8:1:3::5')
    assert_equal 'nesmysl', DeviceLogin.ip_bucket('nesmysl')
    assert_equal '', DeviceLogin.ip_bucket(nil)
    assert_equal '1.2.3.4', DeviceLogin.ip_bucket('::ffff:1.2.3.4')
  end

  test 'same_network?' do
    dl = create(ip: '2001:db8:1:2::5')
    assert dl.same_network?('2001:db8:1:2::9')
    assert_not dl.same_network?('2001:db8:1:3::5')
  end

  test 'create_for! smaže záznamy starší 1 dne' do
    old = travel_to(Time.zone.local(2026, 11, 15, 12, 0, 0)) { create(token: 'stary') }
    travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
      create(token: 'novy')
      assert_not DeviceLogin.exists?(old.id)
    end
  end

  test 'find_pending' do
    travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
      dl = stub_random([3, 17, 0, 21]) { create }
      assert_equal '3-17-0-21', dl.code
      assert_equal dl, DeviceLogin.find_pending([3, 17, 0, 21])
      assert_nil DeviceLogin.find_pending([3, 17, 0, 20])
      assert_nil DeviceLogin.find_pending([1, 2, 3])
      DeviceLogin.where(id: dl.id).update_all(code: '3-17-0-22')
      assert_nil DeviceLogin.find_pending([3, 17, 0, 22])
      DeviceLogin.where(id: dl.id).update_all(code: '3-17-0-21')
      assert_nil DeviceLogin.find_pending(['a', 1, 2, 3])
      assert_nil DeviceLogin.find_pending(nil)
    end
    travel_to Time.zone.local(2026, 11, 17, 12, 5, 0) do
      assert_nil DeviceLogin.find_pending([3, 17, 0, 21])
    end
  end

  test 'approve!' do
    user = make_user
    dl = create
    assert dl.approve!(user)
    assert_equal 'approved', dl.state
    assert_equal user.id, dl.user_id
    assert_not_nil dl.approved_at
    assert_not dl.approve!(user)
    assert_not DeviceLogin.find(dl.id).approve!(user)
  end

  test 'approve! po vypršení selže' do
    dl = travel_to(Time.zone.local(2026, 11, 17, 12, 0, 0)) { create }
    travel_to Time.zone.local(2026, 11, 17, 12, 5, 1) do
      assert_not dl.approve!(make_user)
      assert_equal 'pending', dl.reload.state
    end
  end

  test 'finish!' do
    user = make_user
    travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
      dl = create(token: 'tok')
      dl.approve!(user)
      assert_not dl.finish!('spatny')
      assert dl.finish!('tok')
      assert_equal 'done', dl.state
      assert_not dl.finish!('tok')
    end
  end

  test 'finish! po APPROVE_TTL selže' do
    user = make_user
    dl = travel_to(Time.zone.local(2026, 11, 17, 12, 0, 0)) { create(token: 'tok').tap { |d| d.approve!(user) } }
    travel_to Time.zone.local(2026, 11, 17, 12, 2, 1) do
      assert_not dl.finish!('tok')
      assert_equal 'approved', dl.reload.state
    end
  end

  test 'cancel! by a user only touches unowned or own records' do
    a = make_user('a@example.com')
    b = make_user('b@example.com')
    approved = create(token: 'x').tap { |r| assert r.approve!(b) }
    assert_not approved.cancel!(from: %w[pending approved], by: a)
    assert_equal 'approved', approved.reload.state
    assert_equal b.id, approved.user_id
    assert approved.cancel!(from: %w[pending approved], by: b)
    assert_equal 'cancelled', approved.reload.state
    pending = create(token: 'y')
    assert pending.cancel!(from: %w[pending approved], by: a)
    assert_equal 'cancelled', pending.reload.state
    assert_nil pending.user_id
  end

  test 'cancel!' do
    dl = create
    assert dl.cancel!
    assert_equal 'cancelled', dl.state
    assert_not dl.cancel!
    dl2 = create(token: 'b')
    assert_not dl2.cancel!(from: %w[approved])
    dl2.approve!(make_user)
    assert dl2.cancel!(from: %w[approved])
  end

  test 'finish! bez schválení selže' do
    dl = create(token: 'tok')
    assert_not dl.finish!('tok')
    assert_equal 'pending', dl.reload.state
    dl.cancel!
    assert_not dl.finish!('tok')
    assert_equal 'cancelled', dl.reload.state
  end

  test 'approve! na zrušeném a dokončeném selže' do
    user = make_user
    cancelled = create(token: 'a').tap(&:cancel!)
    assert_not cancelled.approve!(user)
    assert_equal 'cancelled', cancelled.reload.state
    done = create(token: 'b')
    done.approve!(user)
    done.finish!('b')
    assert_not done.approve!(user)
    assert_not done.cancel!
    assert_equal 'done', done.reload.state
  end

  test 'strop pustí 500. platný pending' do
    insert_pending(499, expires_at: 5.minutes.from_now)
    assert_equal 'pending', create.state
    assert_raises(DeviceLogin::Busy) { create(token: 'dalsi') }
  end

  test 'IP limit pustí 30. záznam' do
    insert_pending(29, expires_at: 5.minutes.from_now, ip_bucket: '1.2.3.4')
    assert_equal 'pending', create.state
    assert_raises(DeviceLogin::Busy) { create(token: 'dalsi') }
  end

  test 'IPv6 adresy v jedné /64 sdílí IP limit' do
    15.times { |i| create(token: "a#{i}", ip: '2001:db8:1:2::5') }
    15.times { |i| create(token: "b#{i}", ip: '2001:db8:1:2::9') }
    assert_raises(DeviceLogin::Busy) { create(token: 'c', ip: '2001:db8:1:2::abcd') }
    assert_equal 'pending', create(token: 'd', ip: '2001:db8:1:3::5').state
  end

  test 'expires_in není záporné' do
    dl = travel_to(Time.zone.local(2026, 11, 17, 12, 0, 0)) { create }
    travel_to(Time.zone.local(2026, 11, 17, 12, 10, 0)) { assert_equal 0, dl.expires_in }
  end

  test 'approve_expires_in počítá 2 min od schválení, jinak 0' do
    dl = travel_to(Time.zone.local(2026, 11, 17, 12, 0, 0)) { create }
    assert_equal 0, dl.approve_expires_in
    travel_to(Time.zone.local(2026, 11, 17, 12, 1, 0)) { assert dl.approve!(make_user) }
    travel_to(Time.zone.local(2026, 11, 17, 12, 1, 0)) { assert_equal 120, dl.approve_expires_in }
    travel_to(Time.zone.local(2026, 11, 17, 12, 2, 30)) { assert_equal 30, dl.approve_expires_in }
    travel_to(Time.zone.local(2026, 11, 17, 12, 10, 0)) { assert_equal 0, dl.approve_expires_in }
  end

  test 'device_label' do
    assert_equal 'Android · Chrome', DeviceLogin.new(user_agent: ANDROID_CHROME).device_label
    assert_equal 'iPhone · Safari', DeviceLogin.new(user_agent: IPHONE_SAFARI).device_label
    assert_equal 'Windows · Edge', DeviceLogin.new(user_agent: WINDOWS_EDGE).device_label
    assert_equal 'Linux · Firefox', DeviceLogin.new(user_agent: 'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0').device_label
    assert_equal 'Mac · Safari', DeviceLogin.new(user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15').device_label
    assert_equal 'neznámý systém · neznámý prohlížeč', DeviceLogin.new(user_agent: '').device_label
    assert_equal 'neznámý systém · neznámý prohlížeč', DeviceLogin.new(user_agent: nil).device_label
  end
end

class DeviceLoginAttemptTest < ActiveSupport::TestCase
  def make_user
    User.new(email: 'dla@example.com', password: 'password123', roles: [:user]).tap { |u| u.skip_confirmation!; u.save! }
  end

  test 'limit za minutu' do
    user = make_user
    travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
      5.times { assert DeviceLoginAttempt.begin!(user) }
      assert_nil DeviceLoginAttempt.begin!(user)
      assert_equal 6, DeviceLoginAttempt.where(user_id: user.id, ok: false).count
    end
    travel_to Time.zone.local(2026, 11, 17, 12, 1, 1) do
      assert DeviceLoginAttempt.begin!(user)
    end
  end

  test 'limit za hodinu' do
    user = make_user
    20.times do |i|
      travel_to(Time.zone.local(2026, 11, 17, 12, i * 2, 0)) { assert DeviceLoginAttempt.begin!(user) }
    end
    travel_to(Time.zone.local(2026, 11, 17, 12, 45, 0)) { assert_nil DeviceLoginAttempt.begin!(user) }
    travel_to(Time.zone.local(2026, 11, 17, 13, 3, 0)) { assert DeviceLoginAttempt.begin!(user) }
  end

  test 'begin! smaže pokusy starší 1 dne' do
    user = make_user
    old = travel_to(Time.zone.local(2026, 11, 15, 12, 0, 0)) { DeviceLoginAttempt.begin!(user) }
    fresh = travel_to(Time.zone.local(2026, 11, 16, 13, 0, 0)) { DeviceLoginAttempt.begin!(user) }
    travel_to Time.zone.local(2026, 11, 16, 14, 0, 0) do
      newest = DeviceLoginAttempt.begin!(user)
      assert_nil DeviceLoginAttempt.find_by(id: old.id)
      assert DeviceLoginAttempt.find_by(id: fresh.id)
      assert DeviceLoginAttempt.find_by(id: newest.id)
    end
  end

  test 'úspěšné se nepočítají' do
    user = make_user
    travel_to Time.zone.local(2026, 11, 17, 12, 0, 0) do
      10.times do
        attempt = DeviceLoginAttempt.begin!(user)
        assert attempt
        attempt.succeed!
        assert attempt.reload.ok
      end
      assert DeviceLoginAttempt.begin!(user)
    end
  end
end
