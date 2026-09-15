require 'test_helper'

# RFC 6764 autodiscovery: kořen domény (tep) přesměruje CalDAV/CardDAV
# klienty na OxiCloud DAV pod /sklepox.
class WellKnownDavTest < ActionDispatch::IntegrationTest
  test "caldav well-known redirects to sklepox caldav" do
    get '/.well-known/caldav'
    assert_response :moved_permanently
    assert_includes @response.location, '/sklepox/caldav/'
  end

  test "carddav well-known redirects to sklepox carddav" do
    get '/.well-known/carddav'
    assert_response :moved_permanently
    assert_includes @response.location, '/sklepox/carddav/'
  end
end
