require 'openssl'
module SimpleCrypt

  #stolen from https://gist.github.com/wteuber/5318013
  def self.encrypt(plain_text, key)
    cipher = OpenSSL::Cipher.new('AES-256-CBC').encrypt
    cipher.key = (Digest::SHA512.digest(key))[0..31]
    s = cipher.update(plain_text) + cipher.final
    s.unpack('H*')[0]
  end

  def self.decrypt(cipher_text, key)
    cipher = OpenSSL::Cipher.new('AES-256-CBC').decrypt
    cipher.key = (Digest::SHA512.digest(key))[0..31]
    s = [cipher_text].pack("H*").unpack("C*").pack("c*")
    cipher.update(s) + cipher.final
  end
end
