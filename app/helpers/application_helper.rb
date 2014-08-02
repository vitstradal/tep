# encoding: utf-8
require 'digest/hmac'
module ApplicationHelper

  def ilink_to(text = nil , url = nil, opt = nil, &block)
    url, opt, text = opt, text, capture(&block) if block_given?
    opt ||= {}
    ico = opt.delete(:ico)
    text = content_tag(:i, '', :class=> "ace-icon fa #{ico}") + " " + text if ! ico.nil?
    link_to text, url, opt
  end

  # opt:
  #  ico -- icon class (fa-search)
  #  
  def button_tag (text, opt = {}, &block)
    if block_given?
      opt = text
      text = capture(&block)
    end
    text = content_tag(:span, text, :class => 'hidden-xs')
    ico = opt.delete(:ico);
    tag = opt[:href].nil? ? :button : :a
    opt[:type] ||=  'submit';

    content_tag(tag, opt ) do
       if ico 
         content_tag(:i, '', :class => "ace-icon fa #{ico}") + " " + text
       else
         text
       end
    end
  end
  def menu_lii(uri, text = nil, opt = {} ,  &block)
     opt.merge! ({:lii => true})
     menu_li uri, text, opt, &block
  end

  # opt:
  #  ico
  #  class
  #  lii
  def menu_li(uri, text = nil, opt = {} , &block)

    @_level ||= 1
    @_active ||= false
    li_cls =  opt[:cls].nil? ?  [] :
           opt[:cls].is_a?(String) ? [opt[:cls]] : opt[:cls]

    url =  url_for(uri)

    ico_tag = opt[:ico].nil? ? '' : content_tag(:i, '', { :class => "menu-icon fa #{opt[:ico]}"})

    text_tag = @_level == 2 ? text : content_tag(:span, text, { :class => 'menu-text' }  )

    li_extra = ''
    a_extra = ''
    a_cls = nil

    if block_given?
      li_cls.push('hsub')
      a_cls = "dropdown-toggle"
      a_extra = content_tag(:b, '', {:class => 'arrow fa fa-angle-down'} )
      @_level += 1
      li_extra = \
          content_tag(:b, '', { :class=> "arrow" } )  +
          capture(&block)
      @_level -= 1

       #li_cls.push('open')
       li_cls.push('open active') if @_active
       @_active = false
    end

    if _my_current_page?(url)
      #print "set active\n"
      li_cls.push('active')
      @_active = true
    end

    content_tag(:li, { :class => li_cls.join(' ') } ) do
      content_tag(:a, {:class => a_cls, :href => url}) do
         ico_tag + text_tag + a_extra
      end + li_extra
    end
  end

  private

  def _my_current_page?(uri)
      cur_ori = cur_uri = request.fullpath
      his_uri = url_for(uri)

      return true if cur_uri == his_uri
      return false if his_uri.size < 1

      his_uri = his_uri.sub( /s$/, '')
      his_uri += '/'
      cur_uri += '/'
      ret = cur_uri[0,his_uri.size] == his_uri
      #print "cur: #{cur_uri} cur_ori #{cur_ori}, his: #{his_uri}, ret: #{ret}\n"
      return ret;
  end
end
