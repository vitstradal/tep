#require 'net/http'
require 'net/https'
#require 'net-http-report'
require 'uri'
require 'rexml/document'
require 'rexml/xpath'
require 'selene'
require 'faraday'
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
              result <<   Selene.parse(c.text)['vcalendar'][0]['vevent'][0]
          }
        end
        return result
    end

    private 

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
