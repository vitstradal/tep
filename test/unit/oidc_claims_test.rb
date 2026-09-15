require 'test_helper'

# OIDC claims pro OxiCloud SSO (a další OIDC klienty). Přístup gatuje
# resource_owner_authenticator (jen org); tady testujeme mapování groups
# pro admin roli a základní claims.
class OidcClaimsTest < ActiveSupport::TestCase
  def gen(name)
    Doorkeeper::OpenidConnect.configuration.claims.public_send(name).generator
  end

  test "groups claim maps org and admin roles" do
    assert_equal ['org'], gen(:groups).call(User.new(roles: [:org]), nil, nil)
    assert_equal %w[org admin],
                 gen(:groups).call(User.new(roles: [:org, :admin]), nil, nil)
    assert_equal [], gen(:groups).call(User.new(roles: [:user]), nil, nil)
  end

  test "email_verified reflects confirmation" do
    assert_equal true,  gen(:email_verified).call(User.new(confirmed_at: Time.now), nil, nil)
    assert_equal false, gen(:email_verified).call(User.new(confirmed_at: nil), nil, nil)
  end

  test "identity claims come from user" do
    u = User.new(email: 'org@x.cz', name: 'Jan', last_name: 'Org')
    assert_equal 'org@x.cz', gen(:email).call(u, nil, nil)
    assert_equal 'org@x.cz', gen(:preferred_username).call(u, nil, nil)
    assert_equal 'Jan Org',  gen(:name).call(u, nil, nil)
  end
end
