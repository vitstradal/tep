#!/usr/bin/env ruby

require 'logger'
require 'rest_client'
require 'json'
require './lib/simple_crypt.rb'

$stdout.sync = true
$stdin.sync = true

path = "log/ejabberd-auth.log"
file = File.open(path, File::WRONLY | File::APPEND | File::CREAT)
file.sync = true
logger = Logger.new(file)
logger.level = Logger::DEBUG

def tep_jabber_auth(jid, password, logger)
  auth_url = 'http://pikomat.mff.cuni.cz/jabber/auth'
  auth_url = 'http://localhost:3000/jabber/auth'
  key = 'wax.polish.rescue.elsewhere'
  password = SimpleCrypt.encrypt(password, key)

  logger.error("info: #{jid} #{password}");
  RestClient.post(auth_url, jid: jid, password: password) do  |res, request, err|
    if res.code != 200
      logger.error("bad response #{res.code} #{err}");
      return false
    end
    if res.body.nil?
      logger.error("response body is nil");
      return false
    end
    begin
      js = JSON.parse(res.body)
    rescue
      logger.error("response body is not JSON #{res.body}");
      return false
    end
    return false if js.nil?
    if js['status'] != 'ok'
      logger.error("status is not ok #{res.body}");
      return false
    end
    return true
  end
rescue RestClient::Exception
  return false
end

if ARGV[0] == '-'
  logger = Logger.new(STDOUT)
  puts tep_jabber_auth('adm@pikomat.mff.cuni.cz', 'adm je pes', logger)
  puts tep_jabber_auth('adm@pikomat.mff.cuni.cz', 'adm neni pes', logger)
  exit
end

logger.info "Starting ejabberd authentication service"

loop do
  begin
    $stdin.eof? # wait for input
    start = Time.now

    msg = $stdin.read(2)
    length = msg.unpack('n').first

    msg = $stdin.read(length)
    cmd, *data = msg.split(":")

    logger.info "Incoming Request: '#{cmd}'"
    success = case cmd
    when "auth"
      logger.info "Authenticating #{data[0]}@#{data[1]}"
      auth(data[0], data[2], logger)
    else
      false
    end

    bool = success ? 1 : 0
    $stdout.write [2, bool].pack("nn")
    logger.info "Response: #{success ? "success" : "failure"}"
  rescue => e
    logger.error "#{e.class.name}: #{e.message}"
    logger.error e.backtrace.join("\n\t")
  end
end
