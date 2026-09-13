#!/usr/bin/env ruby
# Vygeneruje RSA klic, kterym doorkeeper-openid_connect podepisuje
# id_tokeny. Stejny vzor jako gen_secret_key_base.rb: soubor je v
# .gitignore, na kazdem prostredi se generuje zvlast.

require 'openssl'

path = 'config/oidc_signing_key.pem'

if File.exist? path
    puts "#{path}: file exists, if you want to regen, remove it first"
    exit
end

File.write(path, OpenSSL::PKey::RSA.new(2048).to_pem)
File.chmod(0o600, path)
puts "OIDC signing key written into #{path}"
