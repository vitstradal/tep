#!/usr/bin/env ruby
#
# ejabberd-auth.rb viz https://www.ejabberd.im/extauth/index.html
#
# debuging:
# ejabberd-auth.rb -

sleep(6000)
begin
require 'logger'
require 'rest_client'
require 'json'
require_relative '../lib/simple_crypt.rb'

# config
#LOG_PATH = File.dirname(__FILE__) + "/../log/ejabberd-auth.log"
LOG_PATH = '/var/log/ejabberd/extauth.log'
#AUTH_URL = 'http://localhost:3000/jabber/auth'
AUTH_URL = 'http://pikomat.mff.cuni.cz/jabber/auth'
KEY = 'wax.polish.rescue.elsewhere'

def tep_jabber_auth(jid, password)
  password = SimpleCrypt.encrypt(password, KEY)

  #LOG.error("info: #{jid} #{password} #{KEY}");
  RestClient.post(AUTH_URL, jid: jid, password: password) do  |res, request, err|
    if res.code != 200
      LOG.error("bad response #{res.code} #{err}");
      return false
    end
    if res.body.nil?
      LOG.error("response body is nil");
      return false
    end
    begin
      js = JSON.parse(res.body)
    rescue
      LOG.error("response body is not JSON #{res.body}");
      return false
    end
    return false if js.nil?
    if js['status'] != 'ok'
      LOG.error("status is not ok #{res.body}");
      return false
    end
    LOG.info("ok auth for #{jid}");
    return true
  end
rescue RestClient::Exception
  return false
end

#######################################
# main

$stdout.sync = true
$stdin.sync = true


#file = File.open(LOG_PATH, File::WRONLY | File::APPEND | File::CREAT)
#file.sync = true
#LOG = Logger.new(LOG_PATH, level: :debug)
LOG = Logger.new(LOG_PATH)
LOG.level = 'debug'
LOG.info "Starting ejabberd authentication service"

if ARGV[0] == '-'
  puts tep_jabber_auth('vitas2@pikomat.mff.cuni.cz', 'vitas2vitas2')
  puts tep_jabber_auth('vitas2@pikomat.mff.cuni.cz', 'adm neni pes')
  exit
end


loop do
  begin
    $stdin.eof? # wait for input
    start = Time.now

    msg = $stdin.read(2)
    length = msg.unpack('n').first

    msg = $stdin.read(length)
    cmd, *data = msg.split(":")

    LOG.info "Incoming Request: '#{cmd}'"
    success = case cmd
    when "auth"
      LOG.info "Authenticating #{data[0]}@#{data[1]}"
      auth(data[0], data[2])
    else
      false
    end

    bool = success ? 1 : 0
    $stdout.write [2, bool].pack("nn")
    LOG.info "Response: #{success ? "success" : "failure"}"
  rescue => e
    LOG.error "#{e.class.name}: #{e.message}"
    LOG.error e.backtrace.join("\n\t")
  end
end
rescue Exception => e 
  File.open('xx', 'w') { |file| file.write("ex:#{e} bt:#{p(e.backtrace_locations)} i:#{e.inspect} m:#{e.message}\n") }
end
