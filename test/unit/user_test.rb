require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "new user has no roles by default" do
    u = User.new(email: 'norole@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    assert_equal [], u.roles.to_a
    assert_not u.user?
  end

  test "explicit roles are kept" do
    u = User.new(email: 'srole@x.cz', password: 'password123', roles: [:user])
    u.skip_confirmation!
    u.save!
    assert u.user?
  end
end
