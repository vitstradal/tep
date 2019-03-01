# encoding: utf-8

require 'unicode_utils'
require 'resolv'

module ApplicationHelper

  ##
  # Vytvoří odkaz na link s iconou.
  #
  # *params*ta
  # text:: text linku
  # url:: kam to bude odkazovat (stejný argument jak má `link_to`) 
  # opt:: stejné jako `link_to` a navíc:
  #       ico:: class z font-awesome jaká icona se má použít (třeba `fa-user`).
  # block:: materiál textu linku
  def ilink_to(text = nil , url = nil, opt = nil, &block)
    url, opt, text = opt, text, capture(&block) if block_given?
    opt ||= {}
    ico = opt.delete(:ico)
    text = content_tag(:span, text, :class=>'hidden-xs')
    text = content_tag(:i, '', :class=> "ace-icon fa #{ico}") + " " + text if ! ico.nil?

    link_to text, url, opt
  end

  ##
  # coutry_code: cz, nebo sk
  #   country_code_to_txt('sk') # => 'Slovensko'
  #   country_code_to_txt('cz') # => nil
  #   country_code_to_txt('blbost') # => 'blbost'
  def country_code_to_txt(country_code)
    return "Slovensko" if country_code  == 'sk'
    return nil if country_code  == 'cz'
    return  country_code
  end


  ##
  # button s iconou, nebo odkaz který vypadá jako button
  #
  # *params*
  # text, block:: text buttonu
  # opt:: opsny pro \<a> (nebo \<button>) a navíc:
  #       ico:: icon class font awesome (`fa-search`)
  #       href:: url, pokud je tag bude \<a>
  #       type:: button type, pokud není bude to 'submit'
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

  ##
  # list item druhé úrovně, viz `menu_li`
  def menu_lii(uri, text = nil, opt = {} ,  &block)
     opt.merge! lii: true
     menu_li uri, text, opt, &block
  end

  ##
  # list item, s iconou a potenciálním active, pokud se aktalní url uzná, že "ma souvislost" s odkazovanou url
  # 
  # *Params*
  # uri:: link kam menu odkazuje
  # text, block:: text
  # opt:: opsny
  #       cls:: string nebo pole stringu, class který se použije v \<li class=""> 
  #       ico:: font awesome class (např. `fa-user`)
  #       lii:: true pokud jde o druhou úroveň (použite z `menu_lii()`
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
    log("alert #{msg}")
  end

  def add_success(msg)
    flash[:success] ||= []
    flash[:success].push(msg)
    log("success #{msg}")
  end

  # allerts for non-redirection
  def add_alert_now(msg)
    flash.now[:alerts] ||= []
    flash.now[:alerts].push(msg)
    log("alert #{msg}")
  end

  def add_success_now(msg)
    flash.now[:success] ||= []
    flash.now[:success].push(msg)
    log("success #{msg}")
  end


  def email_valid_mx_record?(email)
      #mail_servers = Resolv::DNS.open.getresources(email.split('@').last, Resolv::DNS::Resource::IN::MX)
      return false if email.nil? || email == ''
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

  ##
  #
  # nastavi
  # @round:: série
  # @annual:: ročník
  # @config:: hash všech konfiguračních hodnot
  #           annual:: ročník
  #           round:: serie
  #           allow_upload:: je už možný upload v aktuální sérii
  #           show_revisions:: mohou již uživatele vidět opravy
  #           deadlineN::      termín N té serie
  #           showN:: ukaž Ntou serii
  #           problemsN:: počet příkladu v Nté sérii
  #           year:: kalendářní rok
  #           confirmation_round:: serie v které se zobrazí žádost o konfirmaci údajů
  #           confirmation_file_upload:: 
  #           deadline100:: Serie 100 je bonusová
  #           show100::
  #           problems100::
  #           aesop_errors_to:: email komu se posílají errory aesopu
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

  def get_verifier(purpose)
    # FIXME: zde by se mel zamichat aplikacni 'secret
    #kg = ActiveSupport::KeyGenerator.new('fakt-secret:')
    #verifier = ActiveSupport::MessageVerifier.new( kg.generate_key('giwi-secret', 256), digest: 'SHA256')
    verifier = ActiveSupport::MessageVerifier.new('ahoj', serializer: YAML)
    return verifier
  end

  def sign_generate(text, purpose)
    verifier = get_verifier(purpose)
    token = verifier.generate(text)
    log "token:#{token}"
    log "untoken:#{verifier.verify(token)}"
    return token
  end

  def sign_verified(token, purpose)

    return nil if token.nil?

    verifier = get_verifier(purpose)

    # ve verzi rails 5.2:
    #return verifier.verified(token)
    log "token:#{token}"

    plain = verifier.verify(token)
    log "plain:#{plain}"
    return plain

  rescue => ex
    log "exception:#{ex}"
    return nil
  end

  def class_active_if(cond)
     return 'class="active"'.html_safe if cond
  end

  def active_in_if(cond)
     return 'in active' if cond
  end

  def get_sorted_conflict_solvers(annual, round)
      solvers = Sosna::Solver.joins(:solutions => :problem)
                             .where('annual' =>  annual,
                                    'sosna_problems.round' => round,
                                    'solution_form' =>  'tep',
                                    'is_test_solver' =>  false,
                                    'sosna_solutions.has_paper_mail' => true )
                             .group(:id)
                             .load.to_a

      solvers.sort! { |a,b| strcollf(a.last_name, b.last_name) || strcollf(a.name, b.name) || 0 }
  end
  def get_sorted_solvers(where = {})
      solvers = Sosna::Solver.includes(:school).where(where).load.to_a
#      solvers.sort! { |a,b| (a.last_name != b.last_name ) ? strcoll(a.last_name, b.last_name) :
#                                                            strcoll(a.name, b.name)
#                    }
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

  ##
  # helper pro zalogování, level FATAL
  #
  # *Params*
  # msg:: text zprávy
  def log(msg)
    Rails::logger.fatal("  " + msg)
  end

  ##
  # je toto bonusová serie (interně série čislo 100)
  #
  # *Params*
  # round:: číslo série
  #
  # *Returns* true/fal
  def is_bonus_round(round)
    return round.to_s == Sosna::Problem::BONUS_ROUND_NUM.to_s
  end

  ##
  # nahraj hodnotu z Sosna::Config
  #
  # *Params*
  # key:: požadovaná konfigurační hodnota
  #
  # *Returns* hodnotu 
  def config_value(key)
    #return @config[key] if @config
    c = Sosna::Config.where(key:key).first
    return c.value if c
    return nil
  end

  ##
  # najdi řešitele pro daného uživatele (pokud existuje)
  #
  # *Params*
  # user_id:: id uživatele 
  # annual:: ročník (default: `nil`)
  #
  # *Returns* Sosna::Solver / nil
  def find_solver_for_user_id(user_id, annual = nil)
    annual ||= @config[:annual] || config_value(:annual)
    return Sosna::Solver.where(user_id: user_id, annual: annual ).first
  end

  ##
  # najdi řešitele pro daného uživatele (pokud existuje)
  #
  # *Params*
  # user_id:: id uživatele 
  # annual:: ročník (default: `nil`)
  #
  # *Returns* Sosna::Solver / nil
  def breadcrumb_annual_links(action = :index)
     annual_max = @config[:annual].to_i
     annual_min = 29 # tep started
     { name: "Ročník #{@annual}",
       url: {roc:@annual, se: 1},
       sub: (annual_min .. annual_max).map { |a| {name: "Ročník #{a}", url: {action: action, roc:a}}}.reverse,
     }
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
