# encoding: utf-8
require 'digest/hmac'
module ApplicationHelper

  def menu_lii(uri, text = nil, opt = {} ,  &block) 
     opt.merge! ({:lii => true})
     menu_li uri, text, opt, &block
  end

  # opt:
  #  ico
  #  class
  #  lii
  def menu_li(uri, text = nil, opt = {} , &block) 
   
    li_cls =  opt[:cls].nil? ?  [] :
           opt[:cls].is_a?(String) ? [opt[:cls]] : opt[:cls]

    url =  url_for(uri)
    print "XXX:#{url_for(uri)}\t#{current_page?(uri)}\t#{current_page?(url)}\n"



    ico_tag = opt[:ico].nil? ? '' : content_tag(:i, '', { :class => "menu-icon fa #{opt[:ico]}"})

    text_tag = opt[:lii] ? text : content_tag(:span, text, { :class => 'menu-text' }  )

    li_extra = ''
    a_extra = ''
    a_cls = nil

    if block_given? 
      li_cls.push('hsub')
      a_cls = "dropdown-toggle"
      a_extra = content_tag(:b, '', {:class => 'arrow fa fa-angle-down'} ) 
      li_extra = \
          content_tag(:b, '', { :class=> "arrow" } )  +
          capture(&block)

       li_cls.push('open active')
    end

    if current_page?(url)
      print "set active\n"
      li_cls.push('active')
    end

    content_tag(:li, { :class => li_cls.join(' ') } ) do
      content_tag(:a, {:class => a_cls, :href => url}) do
         ico_tag + text_tag + a_extra
      end + li_extra
    end
  end

#  def valid_digest?(data, dig, purpose = 'none')
#     digest(data, purpose) == dig
#  end
#
#  def digest(data, purpose = 'none')
#    config = Tep::Application.config
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
