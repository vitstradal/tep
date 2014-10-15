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

    ico_tag = opt[:ico].nil? ? ''.html_safe : content_tag(:i, '', { :class => "menu-icon fa #{opt[:ico]}"})

    text_tag = @_level == 2 ? text : content_tag(:span, text, { :class => 'menu-text' }  )

    li_extra = ''
    a_extra = ''.html_safe
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

      li_cls.push('open active') if @_active
      @_active = false
    end

    if _my_current_page?(url)
      #print "set active#{url}\n"
      li_cls.push('active')
      @_active = true
    end

    content_tag(:li, { :class => li_cls.join(' ') } ) do
      content_tag(:a, {:class => a_cls, :href => url}) do
          ico_tag  + text_tag + a_extra 
      end + li_extra
    end
  end

  def url_for_root(user = nil)
    user ||= current_user
    #Rails::logger.fatal("user:#{pp(user)}");
    
    if ! user.nil?
      if user.has_role? :admin
        return url_for (wiki_main_path(path: 'org'))
      elsif user.has_role? :org
        return url_for(wiki_main_path(path: 'org'))
      elsif user.has_role? :user
        return url_for(wiki_main_path(path: 'index'))
      end
    end
    return url_for(wiki_main_path(path: 'index'))
  end

  #  like link_to(text, action: :show) for obj
  # but if obj.nil? show only text
  def link_to_show(text, obj_id)
    if obj_id
      link_to text, :action => 'show', :id =>  obj_id
    else
      text
    end
  end
  def deadline_time(cfg, round, ignore_show = false)
    pravek = Time.parse('1975-04-15')
    if ! ignore_show
      s = cfg["show#{round}".to_sym]
      return  pravek if ! s || s != 'yes'
    end
    t = cfg["deadline#{round}".to_sym]
    return pravek if ! t
    return Time.parse(t) + 1.day - 1
  end

  def add_alert(msg)
    flash[:alerts] ||= []
    flash[:alerts].push(msg)
  end

  def add_success(msg)
    flash[:success] ||= []
    flash[:success].push(msg)
  end

  def email_valid_mx_record?(email)
      #mail_servers = Resolv::DNS.open.getresources(email.split('@').last, Resolv::DNS::Resource::IN::MX)
      mail_servers = Resolv::DNS.open.getresources(email.split('@').last.force_encoding('ASCII-8BIT'), Resolv::DNS::Resource::IN::MX)
      return false if mail_servers.empty?
      true
  end

  def translit(str)
    Iconv.iconv('ascii//translit', 'utf-8', str).join
  end
  def self.translit(str)
    Iconv.iconv('ascii//translit', 'utf-8', str).join
  end

  def strcoll(a,b)
    FFILocale::strcoll(a, b) 
  end

  def strcollf(a,b)
    ret = FFILocale::strcoll(a, b) 
    return ret == 0 ? false : ret
  end

  def form_error(obj, *attrs)
    errors = []
    attrs.each {|a| errors.concat(obj.errors.get(a) || [] ) }
    return if errors.empty?
    txt = errors.join(", ")
    return content_tag(:span, txt , class: 'help-inline');
  end
 
  def form_error_class(obj, *attrs)
    attrs.each  do |a|
      return 'control-group error' if ! obj.errors.get(a).nil?
    end
    return 'control-group'
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
  def class_active_if(cond)
     return 'class="active"'.html_safe if cond
  end
end
