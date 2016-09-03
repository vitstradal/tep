# encoding: utf-8
require 'digest/hmac'
require 'unicode_utils'
module ApplicationHelper

  def ilink_to(text = nil , url = nil, opt = nil, &block)
    url, opt, text = opt, text, capture(&block) if block_given?
    opt ||= {}
    ico = opt.delete(:ico)
    text = content_tag(:i, '', :class=> "ace-icon fa #{ico}") + " " + text if ! ico.nil?
    link_to text, url, opt
  end

  # coutry_code: cz, nebo sk
  # r: 'Slovensko' if 'sk'
  # r: nil if 'cz'
  # r: coutry_code jinak
  def country_code_to_txt(country_code)
    return "Slovensko" if country_code  == 'sk'
    return nil if country_code  == 'cz'
    return  country_code
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
     opt.merge! lii: true
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
    #log("user:#{pp(user)}")
    load_config

    if ! user.nil?
      if user.has_role? :admin
        return url_for (wiki_piki_path(path: 'org'))
      elsif user.has_role? :org
        return url_for(wiki_piki_path(path: 'org'))
      elsif user.has_role? :user
        #Rails::logger.fatal("show100:"+ config_value('show100'))
        if config_value('show100') == 'yes'
          solver = find_solver_for_user_id(user.id)
          #Rails::logger.fatal("solver"+pp(solver))
          if !solver.nil? && solver.confirm_state == 'bonus'
            return url_for(:sosna_solutions_user_bonus)
          end
        end 
        return url_for(:sosna_solutions_user)
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
    log("deadline round #{round}, #{cfg}, #{cfg[:deadline1]}")
    if ! ignore_show
      s = cfg["show#{round}".to_sym]
      log("deadline round s:  #{s}")
      return  nil if ! s || s != 'yes'
    end
    t = cfg["deadline#{round}".to_sym]
    log("deadline round t:  #{t}")
    return nil if ! t
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
    UnicodeUtils.nfkd(str).gsub(/(\p{Letter})\p{Mark}+/,'\\1')
  end

  def strcoll(a,b)
    return FFILocale::strcoll(a, b)
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

  def load_config
    return if @config
    @config  =  { annual:20,
                  round: 1,
                  show_revisions: 'no',
                }
    Sosna::Config.all.load.each {|c| @config[c.key.to_sym] =  c.value}
    @annual = @config[:annual]
    @round = @config[:round]
    #log( "config: #{@config}" )
  end

  def get_sorted_solvers(where = {})
      solvers = Sosna::Solver.includes(:school).where(where).load.to_a
      solvers.sort! { |a,b| (a.last_name != b.last_name ) ? strcoll(a.last_name, b.last_name) :
                                                            strcoll(a.name, b.name)
                    }
      solvers.sort! { |a,b| strcollf(a.last_name, b.last_name) || strcollf(a.name, b.name) || 0 }
  end

  def heading_with_tools(title, &block)
    body = capture(&block)
    content_tag(:div, :class => "widget-box transparent collapsed") do
      content_tag(:div, :class => "widget-header widget-header-flat") do
        content_tag(:h4, title, :class => "widget-title") +
        content_tag(:div, :class => "widget-toolbar") do
          content_tag(:a, href: '#', 'data-action' => 'collapse') do
             content_tag(:i, ' ', :class => 'ace-icon fa fa-dashboard')
          end
        end
      end +
      content_tag(:div, :class => "widget-body") do
        content_tag(:div, :class => "row") do
          content_tag(:div, :class => "col-xs-12") do
           capture(&block)
          end
        end
      end
    end
  end

  def log(msg)
    Rails::logger.fatal("  " + msg)
  end

  def is_bonus_round(round)
    return round.to_s == '100'
  end

  def config_value(key)
    #return @config[key] if @config
    c = Sosna::Config.where(key:key).first
    return c.value if c
    return nil
  end

  def find_solver_for_user_id(user_id, annual = nil)
    annual ||= @config[:annual] || config_value(:annual)
    return Sosna::Solver.where(user_id: user_id, annual: annual ).first
  end

end
