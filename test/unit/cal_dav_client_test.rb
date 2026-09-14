require 'test_helper'
require 'cal_dav_report'

# Testy CalDAV klienta bez sítě: skládání VEVENT (round-trip přes icalendar)
# a parsování REPORT odpovědi z fixtury. HTTP proti živému CalDAV se ověřuje
# ručně (curl / integrace s OxiCloudem).
class CalDavClientTest < ActiveSupport::TestCase
  test "build_vevent produces parseable timed event" do
    uid = CalDavReport.new_uid
    ical = CalDavReport.build_vevent(
      uid: uid, summary: 'Schůzka orgů',
      dtstart: DateTime.new(2026, 10, 5, 18, 0, 0),
      dtend:   DateTime.new(2026, 10, 5, 20, 0, 0),
      description: 'https://pikomat.mff.cuni.cz/wiki')
    ev = Icalendar::Calendar.parse(ical).first.events.first
    assert_equal uid, ev.uid.to_s
    assert_equal 'Schůzka orgů', ev.summary.to_s
    assert_equal 'https://pikomat.mff.cuni.cz/wiki', ev.description.to_s
    assert_instance_of Icalendar::Values::DateTime, ev.dtstart
    assert_equal 2026, ev.dtstart.year
    assert_equal 18, ev.dtstart.hour
  end

  test "build_vevent all_day uses DATE value" do
    ical = CalDavReport.build_vevent(
      uid: 'x', summary: 'Tábor',
      dtstart: Date.new(2026, 7, 1), dtend: Date.new(2026, 7, 15), all_day: true)
    ev = Icalendar::Calendar.parse(ical).first.events.first
    assert_instance_of Icalendar::Values::Date, ev.dtstart
    assert_equal Date.new(2026, 7, 1), ev.dtstart.value
  end

  test "new_uid is unique" do
    assert_not_equal CalDavReport.new_uid, CalDavReport.new_uid
  end

  test "_event_path appends uid.ics to collection, escaping" do
    rep = CalDavReport.new('https://h/caldav/cal/')
    assert_equal '/caldav/cal/abc.ics', rep.send(:_event_path, 'abc')
    # bez koncového lomítka i s znakem k escapování
    rep2 = CalDavReport.new('https://h/caldav/cal')
    assert_equal '/caldav/cal/a%2Fb.ics', rep2.send(:_event_path, 'a/b')
  end

  test "_headers adds Basic auth only with credentials" do
    anon = CalDavReport.new('https://h/caldav/cal')
    assert_nil anon.send(:_headers)['Authorization']
    authed = CalDavReport.new('https://h/caldav/cal', 'svc', 'heslo')
    assert_equal 'Basic ' + Base64.strict_encode64('svc:heslo'),
                 authed.send(:_headers)['Authorization']
  end
end
