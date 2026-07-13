require 'test_helper'

class FriendTest < ActiveSupport::TestCase
  test "create generates uuid and strips nick" do
    f = Friend.create!(nick: '  Petr  ')
    assert f.uuid.present?
    assert_equal 'Petr', f.nick
  end

  test "uuid must be unique" do
    f = Friend.create!(nick: 'Petr')
    dup = Friend.new(nick: 'Jiny', uuid: f.uuid)
    assert_not dup.valid?
  end

  test "user_id unique, one friend per user" do
    u = User.new(email: 'f@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    Friend.create!(nick: 'Petr', user: u)
    dup = Friend.new(nick: 'Jiny', user: u)
    assert_not dup.valid?
  end

  test "status ladder" do
    assert_equal 'anonymous', Friend.create!(nick: 'A').status

    u = User.new(email: 'g@x.cz', password: 'password123')
    u.save!  # neověřený
    f = Friend.create!(nick: 'B', user: u)
    assert_equal 'unverified', f.status

    u.confirm
    assert_equal 'verified', f.reload.status
  end

  test "discriminator is short and stable" do
    f = Friend.create!(nick: 'Petr')
    assert_match(/\A[0-9a-f]{2}\z/, f.discriminator)
    assert_equal f.discriminator, f.discriminator
  end
end
