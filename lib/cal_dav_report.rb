#require 'net/http'
require 'net/https'
#require 'net-http-report'
require 'uri'
require 'rexml/document'
require 'rexml/xpath'
#require 'selene'
require 'icalendar'
require 'faraday'
require 'base64'
require 'securerandom'
require 'cgi'
require 'pp'

#
# toto je hack jak ziskat polozky calendare pomoc caldav (http)
# rep = CalDavReport('https://pikomat.mff.cuni.cz/sklep/remote.php/dav/public-calendars/0HCE3AI7EK2F7J2D', nil, nil);
# pp rep2.report('20111101T000000', '20181231T000000')
# => 
# {"created"=>"20130902T190329Z",
#   "last-modified"=>"20130902T190330Z",
#   "uid"=>"usr44jjenaqodfmc8vjbrjumvk",
#   "summary"=>"Chrismas morning -- bíla",
#   "status"=>"CONFIRMED",
#   "organizer"=>"mailto:obp69n6p6u6sb2or572k78mvns@group.calendar.google.com",
#   "dtstart"=>["20131211", {"value"=>"DATE", "tzid"=>"Europe/Prague"}],
#   "dtend"=>["20131212", {"value"=>"DATE", "tzid"=>"Europe/Prague"}],
#   "sequence"=>"0",
#   "x-google-editurl"=>
#    "https://www.google.com/calendar/feeds/obp69n6p6u6sb2or572k78mvns%40group.calendar.google.com/private/full/usr44jjenaqodfmc8vjbrjumvk/63513831810",
#   "url"=>
#    "https://www.google.com/calendar/event?eid=dXNyNDRqamVuYXFvZGZtYzh2amJyanVtdmsgb2JwNjluNnA2dTZzYjJvcjU3Mms3OG12bnNAZw",
#   "transp"=>"TRANSPARENT",
#   "class"=>"DEFAULT"},
# {"created"=>"20130902T190045Z",
#   "last-modified"=>"20130902T190046Z",
#   "uid"=>"v9ghnqlb1vqt45gd55iakl1a4o",
#   "summary"=>"žlutá",
#   "status"=>"CONFIRMED",
#   "organizer"=>"mailto:obp69n6p6u6sb2or572k78mvns@group.calendar.google.com",
#   "dtstart"=>["20130911", {"value"=>"DATE", "tzid"=>"Europe/Prague"}],
#   "dtend"=>["20130912", {"value"=>"DATE", "tzid"=>"Europe/Prague"}],
#   "sequence"=>"0",
#   "x-google-editurl"=>
#    "https://www.google.com/calendar/feeds/obp69n6p6u6sb2or572k78mvns%40group.calendar.google.com/private/full/v9ghnqlb1vqt45gd55iakl1a4o/63513831646",
#   "url"=>
#    "https://www.google.com/calendar/event?eid=djlnaG5xbGIxdnF0NDVnZDU1aWFrbDFhNG8gb2JwNjluNnA2dTZzYjJvcjU3Mms3OG12bnNAZw",
#   "transp"=>"TRANSPARENT",
#   "class"=>"DEFAULT"}
# ]
#

module Faraday
    class Connection
            METHODS.add(:report)
    end
end

class CalDavReport
    def initialize(url,  user = nil, password = nil)
       @uri = URI(url)
       @user = user
       @password = password 
    end
   
    def report start, stop
        #Faraday::Connection::METHODS.add(:report)
        conn = Faraday.new(:url => "#{@uri.scheme}://#{@uri.host}", ssl: { verify: false } )
        resp = conn.run_request(:report, @uri.path, _report_body(start, stop), {'Content-Type'=>'application/xml', 'Depth' => '1'} ) 
        result = []
        xml = REXML::Document.new( resp.body )
        begin 
          REXML::XPath.each( xml, '//c:calendar-data/', { "c"=>"urn:ietf:params:xml:ns:caldav"} ) { |c|
              c_parsed = Icalendar::Calendar.parse(c.text)[0].events[0]
              #c_parsed = Selene.parse(c.text)['vcalendar'][0]['vevent'][0]
              #c_parsed['_orig'] = c.text
              result <<  c_parsed
          }
        end
        return result
    end

    ##
    # Klikací kalendář (viz Cal::EventsController). Čte i zapisuje na CalDAV
    # kolekci @uri (dnes Nextcloud/sklep, cílově OxiCloud /caldav). Zápis
    # vyžaduje user/password (service app-heslo); veřejné čtení ne.

    # Seznam událostí v rozsahu jako pole hashů se vším, co UI potřebuje
    # (uid pro editaci/smazání, etag pro optimistický zámek). Na rozdíl od
    # `report` (které vrací Icalendar objekty pro wiki) je to plochý JSON-ready
    # tvar pro FullCalendar.
    def list(start, stop)
        resp = _conn.run_request(:report, @uri.path, _report_body(start, stop),
                                 _headers('Content-Type' => 'application/xml', 'Depth' => '1'))
        raise "CalDAV REPORT #{@uri.path}: #{resp.status}" unless resp.success?
        xml = REXML::Document.new(resp.body)
        events = []
        REXML::XPath.each(xml, '//d:response', { 'd' => 'DAV:' }) do |r|
            etag = REXML::XPath.first(r, './/d:getetag/text()', { 'd' => 'DAV:' })&.value
            data = REXML::XPath.first(r, './/c:calendar-data/text()',
                                      { 'c' => 'urn:ietf:params:xml:ns:caldav' })&.value
            next unless data
            ev = Icalendar::Calendar.parse(data).first&.events&.first
            next unless ev
            events << {
                uid:         ev.uid&.to_s,
                etag:        etag,
                summary:     ev.summary&.to_s,
                description: ev.description&.to_s,
                dtstart:     ev.dtstart&.value_ical,
                dtend:       ev.dtend&.value_ical,
                all_day:     ev.dtstart.is_a?(Icalendar::Values::Date),
            }
        end
        events
    end

    # Vytvoř/uprav událost. uid je zároveň jméno .ics zdroje (idempotentní
    # upsert). Vrací etag z odpovědi.
    def put_event(uid, ical)
        resp = _conn.put(_event_path(uid), ical,
                         _headers('Content-Type' => 'text/calendar; charset=utf-8'))
        raise "CalDAV PUT #{_event_path(uid)}: #{resp.status}" unless resp.success?
        resp.headers['etag']
    end

    def delete_event(uid)
        resp = _conn.delete(_event_path(uid), nil, _headers)
        # 404 = už neexistuje → bereme jako úspěch (idempotentní smazání)
        return true if resp.success? || resp.status == 404
        raise "CalDAV DELETE #{_event_path(uid)}: #{resp.status}"
    end

    # Postav VEVENT (jeden .ics) z parametrů z UI. all_day → DATE bez času.
    def self.build_vevent(uid:, summary:, dtstart:, dtend:, description: nil, all_day: false)
        cal = Icalendar::Calendar.new
        cal.prodid = '-//Pikomat//tep kalendar//CS'
        cal.event do |e|
            e.uid = uid
            e.summary = summary.to_s
            if all_day
                e.dtstart = Icalendar::Values::Date.new(dtstart)
                e.dtend   = Icalendar::Values::Date.new(dtend)
            else
                e.dtstart = Icalendar::Values::DateTime.new(dtstart)
                e.dtend   = Icalendar::Values::DateTime.new(dtend)
            end
            e.description = description.to_s unless description.to_s.empty?
        end
        cal.to_ical
    end

    def self.new_uid
        "#{SecureRandom.uuid}"
    end

    private

    # Faraday spojení na host:port kolekce; port bereme z URI (u OxiCloudu
    # na localhostu není 443). ssl verify off — interní/self-signed cíle.
    def _conn
        Faraday.new(url: "#{@uri.scheme}://#{@uri.host}:#{@uri.port}",
                    ssl: { verify: false })
    end

    # Přidej Basic auth hlavičku, jen když máme credentials (veřejné čtení bez).
    def _headers(extra = {})
        return extra unless @user
        extra.merge('Authorization' =>
            'Basic ' + Base64.strict_encode64("#{@user}:#{@password}"))
    end

    def _event_path(uid)
        base = @uri.path.end_with?('/') ? @uri.path : "#{@uri.path}/"
        "#{base}#{CGI.escape(uid.to_s)}.ics"
    end

    def _report_body start, stop
        """<?xml version='1.0'?>
<c:calendar-query xmlns:c='urn:ietf:params:xml:ns:caldav'>
  <d:prop xmlns:d='DAV:'>
    <d:getetag/>
    <c:calendar-data>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name='VCALENDAR'>
      <c:comp-filter name='VEVENT'>
        <c:time-range start='#{start}Z' end='#{stop}Z'/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>
"""
   end
end
