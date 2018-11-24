require 'net/http'
require 'uri'
require 'base64'

Debug = false

module SimpleBoshSession
  def self._req1(rid, dom)
    <<EOL
    <body content="text/xml; charset=utf-8"
          hold="1"
          rid="#{rid}"
          to="#{dom}"
          ver="1.6"
          wait="60"
          xml:lang="en"
          xmlns="http://jabber.org/protocol/httpbind"
          xmlns:xmpp="urn:xmpp:xbosh"
          xmpp:version="1.0"/>
EOL
  end
  
  def self._req2(rid,sid,digest)
    <<EOL
    <body rid="#{rid}"
          sid="#{sid}"
          xmlns="http://jabber.org/protocol/httpbind">
      <auth mechanism="PLAIN" xmlns="urn:ietf:params:xml:ns:xmpp-sasl">#{digest}</auth>
    </body>
EOL
  end
  
  # bost_url 'http://127.0.0.1:5280/bosh' 
  # jid vitas@pikomat.mff.cuni.cz
  # pass ...
  def self.get_session(bosh_url, jid, pass)
  
    nick, dom = jid.split(/@/, 2)
    uri = URI(bosh_url)
    rid = rand(1000000)
  
    
    res1 = Net::HTTP.post uri, _req1(rid, dom), 'Content-Type' =>  'text/xml; charset=utf-8'
    body = res1.body
  
    return [nil, nil] if body !~ /sid=['"]([^'"]*)['"]/
    sid = $1
  
    puts sid if Debug
    
    rid+=1
  
    digest = Base64.strict_encode64 "#{jid}\0#{nick}\0#{pass}"
    res2 = Net::HTTP.post uri, _req2(rid, sid, digest), 'Content-Type' =>  'text/xml; charset=utf-8'
  
    puts res2.body if Debug
    return [rid,sid] if res2.body =~ /<success[^>]*>/
    return [nil,nil]
  end

end

#rid, sid = SimpleBoshSession.get_session('http://127.0.0.1:5280/bosh', 'vitas2@pikomat.mff.cuni.cz', 'vitas2vitas2')
#puts "rid=#{rid}"
#puts "sid=#{sid}"
