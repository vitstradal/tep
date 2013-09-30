# encoding: utf-8
require 'digest/hmac'
module ApplicationHelper

#  def valid_digest?(data, dig, purpose = 'none')
#     digest(data, purpose) == dig
#  end
#
#  def digest(data, purpose = 'none')
#    config = Pia::Application.config
#    key = Digest::HMAC.base64digest(config.secret_token+ "::" + purpose, "key", Digest::SHA256)
#    _b64_to_b64u(Digest::HMAC.base64digest(data, key, Digest::SHA256))
#  end
#
#  def send_invitation_mail(email, roles)
#      print "url:", sign("email\0roles", 'invitation')
#  end
#
#  def create_invated_user!(email, roles, pass, digest)
#    if valid_digest?("email\0roles", 'invitation')
#      user = User.create(email: email, roles: roles.split('|'), password: pass)
#      user.confirm!
#      sign_in user
#    end
#  end
#
#  def _b64_to_b64u(txt)
#     txt.tr('+/', '-_').tr('=','')
#  end
end
