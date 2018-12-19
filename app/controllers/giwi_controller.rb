# encoding: utf-8

require 'trac-wiki'
require 'pp'
require 'faraday'
require 'iconv'
require 'json'
require 'yaml'
require 'caldavreport'
#require 'magick_title'

class GiwiController < ApplicationController
  include ApplicationHelper
  def initialize
     # https://github.com/citrus/magick_title
     MagickTitle.options[:font_size] = 15
     MagickTitle.options[:color] = '#000000'
     MagickTitle.options[:font_path] = 'public/stylesheets/andulka'
     MagickTitle.options[:background_alpha] = '00'
     MagickTitle.options[:font] = 'andulkabook-webfont.ttf'
     MagickTitle.options[:font] = 'andulkabook-webfont.ttf'
     MagickTitle.options[:destination] = 'public/mails'
     super
  end

  def show_root ;
    show
  end
  def update_root
    update
  end

  def show
    @wiki = params[:wiki] || 'main'
    @giwi = Giwi.get_giwi(@wiki)
    @cursor = params[:cursor]
    auth_name = @giwi.auth_name

    authorize! :show, auth_name

    @can_update = can? :update, auth_name
    @editable = @can_update

    @path = params[:path]

    @edit = params[:edit] || false
    @ls   = params[:ls]
    @history  = params[:history]
    @diff  = params[:diff]
    @part = false
    @cache = params[:cache] || ''

    fmt = params[:format]

    if @cache == 'clear' && @can_update
      _cache_clear
      add_alert "Wiki parse cache was cleared #{@wiki}:#{@path}"
      #FIXME: nefunguje v main wiki (ignoruje @path)
      #FIXME: csrf
      return redirect_to(action: :show, path: @path, wiki: @wiki)
    end

    return _handle_preview(params[:preview])  if ! params[:preview].nil?
    return _handle_ls if @ls
    return _handle_history if @history
    return _handle_diff if @diff
    return _handle_csrf if fmt == 'csrf'
    return _handle_special_edit(@path, fmt) if @edit && %w(svg).include?(fmt)

    return _handle_raw_file("#{@path}.#{fmt}", fmt) if %w(json pdf png jpg jpeg gif svg pik).include? fmt

    return redirect_to action: :show, path: @path + 'index',  wiki: @wiki if @path =~ /\/$/
    return redirect_to action: :show, path: 'index',  wiki: @wiki if ! @path

    _breadcrumb_from_path(@path)

    if @edit && @can_update
      _handle_edit
      return render :edit, formats:[:html]
    end

    path_ext = @path + @giwi.ext
    log "path:#{path_ext}"
    @text, @version = @giwi.get_page(path_ext)

    if ! @text
      path_idx  = @path + '/index'
      if @giwi.file?(path_idx + @giwi.ext)

         @path = path_idx
         path_ext = @path + @giwi.ext
         @text, @version = @giwi.get_page(path_ext)

      else
        return _create_new_page_text if  @can_update
        return _not_found
      end
    end
    @path = path_ext

    page = _cached_or_parse_and_cache

    @html              = page[:html]
    @toc               = page[:toc]
    @headings          = page[:headings]
    @tep_index         = page[:tep_index]
    @wide_display      = page[:wide_display]
    @foto_gallery      = page[:foto_gallery]
    @redirect_to       = page[:redirect_to]
    @background_image  = page[:background_image]
    @nocache           = page[:nocache]

    return _handle_redirect(@redirect_to) if @redirect_to

    @no_sidebar = true if @tep_index


    return render :json => { :html =>  @html } if params[:format] == 'json' && @can_update
    render :show
  end


  def _handle_diff
    authorize! :update, @giwi.auth_name
    @giwi = Giwi.get_giwi(@wiki)
    if @diff == 'LAST'
      history = @giwi.get_history(count: 1)
      @diff = history[0][:commit] if history.size > 0
    end
    @diff_lines = @giwi.get_diff(@diff)
    return render :diff
  end

  def _handle_history
    authorize! :update, @giwi.auth_name
    @giwi = Giwi.get_giwi(@wiki)
    @history = @giwi.get_history
    return render :history
  end

  # aktualizace stranky
  # @param version verze (git-id) ze ktre se pri editaci vychazi
  # @param file pokud jde o upload
  # @param preview pozadovano je pouze preview, hodnota je wikitext, navrat bude json `{html=>'..'}`
  # @param data obsah ukladaneho souboru, ale v parametru (pro
  # @param text text aktualizovaneho textu
  # @param pos pozice puvodniho textu v originale (ve verzi `version`), format pozice:
  #   `pos` in form `3.0-44.20` "from start of line 3 to line 44 char 20";
  #   `pos` in form `3-44` "from start of line 3 to start line 44 (inc \n)";
  #   `pos` in form `3.4` "insert at line 3 after char 4";
  #
  def update
    @wiki = params[:wiki] || 'main'
    @giwi = Giwi.get_giwi(@wiki)

    authorize! :update, @giwi.auth_name

    fmt = params[:format]
    file = params[:file]
    filename = params[:filename]
    version = params[:version]
    @path = params[:path]
    data = params[:data]
    pos = params[:pos]

    return _handle_preview(params[:preview]) if ! params[:preview].nil?
    return _handle_file_upload(data, "#{@path}.#{fmt}", nil, false) if data
    return _handle_file_upload(file.read, filename, file.original_filename ) if file
    return _handle_file_delete(filename, version, current_user.full_email) if params[:delete]

    text = params[:text_inline] || params[:text] || ''
    text.gsub!(/\r\n?/,"\n")
    text += "\n" if text[-1] != "\n"

    email = current_user.full_email
    status = @giwi.set_page(@path + @giwi.ext, text, version, email, pos)

    if @giwi.cache_killer?
      add_alert 'Wiki parse cache was cleared'
      _cache_clear
    else
      if @giwi.cache?
        _cache_delete version
      end
    end

    if status !=  Giwi::SETPAGE_OK
      if status ==  Giwi::SETPAGE_MERGE_OK
         add_alert "Pozor: při editaci nastala kolize, ale podařilo se jí automaticky vyřešit"
      elsif status ==  Giwi::SETPAGE_MERGE_COLLISONS
         add_alert "Pozor: při editaci nastala kolize, kolize je vyznačena v textu, editací uveď soubor do rozumného stavu"
      elsif status ==  Giwi::SETPAGE_MERGE_DIFF
         add_alert "Pozor: při editaci nastala kolize, rozdíl verzí byl připojen na konec souboru"
      else
         add_alert "Pozor: při editaci nastala kolize, a celé se to rozsypalo"
      end
    end

    edit = (params[:edit]||'') == '' ? nil : params[:part] || 'me'
    cursor = (params[:cursor]||'') == '' ? nil : params[:cursor]

    if ! edit && params[:part]
      redirect_to action: :show,  wiki: @wiki, path: @path, cursor: cursor, anchor: "h#{params[:part]}"
    else
      redirect_to action: :show,  wiki: @wiki, path: @path, cursor: cursor, edit: edit
    end
  end

  private
  def _handle_file_delete(filename, version, email)
    status = @giwi.set_page(filename, nil, version, email)
    redirect_to action: :show,  wiki: @wiki, path: @path, ls: '.'
  end

  def _handle_redirect(redir)
    log "redir:#{redir}"
    return redirect_to url_for(redir) if redir =~ /^\//
    return redirect_to wiki_main_path(redir) if @wiki.to_s == 'main'
    return redirect_to url_for(action: :show, wiki: @wiki, path: redir)
  end

  def _handle_special_edit(path, fmt)
    authorize! :update, @giwi.auth_name
    uri = url_for(wiki: @wiki, path: '/', :only_path => true).gsub(/\/+$/, '')
    if fmt == 'svg'
      redirect_to "/tools/svg-edit-2.7.1/svg-editor.html?url=#{uri}/#{path}.#{fmt}"
    elsif fmt == 'sheet'
      redirect_to "/tools/jQuery.sheet/sheet-editor.html?url=#{uri}/#{path}.#{fmt}"
    end
  end

  def _handle_csrf
    authorize! :update, @giwi.auth_name
    render json: {:csrf => form_authenticity_token.to_s  }
  end

  def _handle_raw_file(path, fmt)
    @raw, @version = Giwi.get_giwi(@wiki).get_page(path)
    send_data @raw, :type => fmt.to_sym, :disposition => 'inline'
  end

  def _get_parser
    TracWiki.parser(_trac_wiki_options)
  end

  def _trac_wiki_options
    base = (@wiki.to_s == 'main') ? url_for(:root) : url_for(action: :show, wiki: @wiki)
    root = url_for(:root)
    { base: base,
      root: root,
      math: true,
      merge: true,
      edit_heading: @editable,
      id_from_heading: true,
      id_translit: true,
      no_escape: true,
      allow_html: true,
      div_around_table: true,
      template_handler: self.method(:_template_handler),
    }
  end

  def _template_handler(tname, env, argv)

    return _template_textimg(env, argv) if tname == 'textimg'
    return _template_fakecrypt(env, argv) if tname == 'fakecrypt'
    return _template_include(env, argv) if tname == 'include'
    return _template_calendar(env, argv) if tname == 'owncalendar'

    part = 0
    if tname =~ /\A\//
      tname = $'
      part = 1
    end
    giwi = @giwi
    if @giwi.templates
      giwi = Giwi.get_giwi(@giwi.templates)
      template_path = tname + giwi.ext
    else
      template_path = '.template/' + tname + giwi.ext
    end

    text, _ = giwi.get_page(template_path)

    # not found
    return nil if text.nil?

    while part >= 0

      #return only single line
      ret, text = text.split(/\r?\n/, 2)

      # macro enclosed in {{{ }}}
      if  ret == '{{{'
        ret, text = text.split(/\r?\n\}\}\}\r?\n?/, 2)
      end

      return ret if part == 0
      part -= 1
    end
  end

  # usage: {{calendar URL | mon=3}}
  # 3 mesice dopredu (from now)
  def _template_calendar(env, argv)
    begin
      url =  argv['0']
      mon =  argv['mon']

      now  = Date.today
      pak =  now.next_month((mon||1).to_i)

      now_f = now.strftime('%Y%m%dT000000')
      pak_f = pak.strftime('%Y%m%dT000000')

      # fetch events
      repo = CalDavReport.new(url)
      events = repo.report( now_f, pak_f)

      # prepare 'start' and sort
      events.each do |event|
            start = event['dtstart'][0]
            start = Date.parse(start).strftime("%F") if ! start.nil?
            event['start'] = start
      end
      events.sort! { |a,b| a['start'] <=> b['start'] }

      # render
      events.map do |event|
            start = event['start']
            summary = event['summary']
            url = event['description'] || ''
            if url =~ /(https?:\/\/\S*)/
              "* **#{start}** [[#{$1} | #{summary}]]\n"
            else
              "* **#{start}** #{summary}\n"
            end
      end.join
    rescue Exception => e
      ". (#{e.message}, #{e.to_s}, #{pp(e.backtrace)})"
    end
  end

#  def _template_calendar(env, argv)
#    begin
#      now  = Date.today
#      nm =  now.next_month((argv['mon']||1).to_i)
#      cal =  argv['cal'] || 'resitel'
#
#      conn = Faraday.new('https://pikomat.mff.cuni.cz', ssl: { verify: false } )
#      # https://pikomat.mff.cuni.cz/sklep/index.php/apps/ownhacks/public?cal=resitel&start=1493856000&end=1493956000
#      resp = conn.get('/sklep/index.php/apps/ownhacks/public', cal: cal ,start: now.strftime('%s'), end: nm.strftime('%s'))
#      Rails.logger.fatal("calendar cal=#{cal}&start=#{now.strftime('%s')}&end=#{nm.strftime('%s')}")
#
#      json = JSON.load(resp.body)
#      #"/sklep/index.php/apps/ownhacks/calendar-10.php?start=#{now.strftime('%s')}&end=#{nm.strftime('%s')}\n" +
#      env['nocache'] = '1'
#      json.sort {|a,b| a['start'] <=> b['start'] }.map do |item|
#          url = item['description']
#          if url =~ /(https?:\/\/\S*)/
#            "* **#{item['start']}** [[#{$1} | #{item['title']}]]\n"
#          else
#            "* **#{item['start']}** #{item['title']}\n"
#          end
#      end.join
#    rescue Exception => e
#      '.' #e.message
#    end
#
#  end

  def _template_include(env, argv)
    env['nocache'] = '1'
    path =  argv['00']
    text, _ = @giwi.get_page(path + @giwi.ext)
    return "no such page (#{path})" if text.nil?
    return text
  end
  def _template_fakecrypt(env, argv)
    return argv['00'].tr('A-Z', 'L-ZA-K').tr('a-z', 'l-za-k').tr('@.-', '512')
  end
  def _template_textimg(env, argv)
    text = argv['00']
    url = MagickTitle.say(text).url
    return ActionController::Base.helpers.asset_path(url)
  end

  def _not_found
    @html = 'not found'
    render :show
  end

  def _handle_preview(wiki)

     authorize! :update, @giwi.auth_name

     parser = _get_parser
     html = parser.to_html(wiki)
     render :json => { :html => html }
  end

  def _handle_file_upload(data, filename, filename_orig, redirect = true)

    authorize! :update, @giwi.auth_name

    if !filename_orig.nil? && ( filename =~ /\/$/ || filename == '' )
      filename += filename_orig
    end

    raise "bad filename #{filename}" if filename =~ /\.\./
    raise "bad filename #{filename}" if filename =~ /^\s*$/

    log "file:#{filename} text.size:#{data.size}, @path: #{@path}"

    flash[:success] ||= []
    flash[:success].push("Soubor #{filename} uložen.")

    email = current_user.full_email
    status = Giwi.get_giwi(@wiki).set_page(filename, data, '', email)
    log "url::#{url_for(action: :show, wiki: @wiki, path: @path, ls: '.')}"

    return redirect_to url_for(action: :show, wiki: @wiki, path: @path, ls: '.') if redirect
    render text: 'tnx'
  end

  def _to_ascii(txt)
      txt.gsub! /\s+/, '_'
      # Iconv.iconv('ascii//translit', 'utf-8', txt).join('')
      # UnicodeUtils.nfkd(txt).gsub(/(\p{Letter})\p{Mark}+/,'\\1')
      # FIXME: dup code with app/helpers/application_helper.rb
      translit txt
  end

  def _handle_ls
    authorize! :update, @giwi.auth_name
    @files, @dirs, @path_dir = Giwi.get_giwi(@wiki).get_ls(@path)
    render :ls
  end

  def _handle_edit

    authorize! :update, @giwi.auth_name

    @text, @version = @giwi.get_page(@path + @giwi.ext)

    base = url_for(action: :show, wiki: @wiki)
    parser = _get_parser
    if @text
      parser.to_html(@text)
      @used_templates = parser.used_templates
      #pp "used templates", @used_templates
    end

    @wide_display = true
    if @edit == 'me'
       @edit = true
       return
    end

    die "wrong edit value" if @edit !~  /^\d+$/

    # want to edit only one chapter
    @part = @edit.to_i

    if @text
      heading = parser.headings[@part]
      if heading
        # edit only selected part (from @sline to @eline)
        @text = @text.split("\n").values_at(heading[:sline]-1 .. heading[:eline]-1).join("\n") + "\n"
        @pos = "#{heading[:sline]}-#{heading[:eline]+1}"
      else
        # edit all document anyway
        @part = nil
      end
    end
  end

  def _create_new_page_text
    @text =
    title = @path.split(/\//).last
    @text = "= #{title.capitalize} =\n\n"
    @path = _to_ascii(@path)
    @edit = true
    @wide_display = true
    render :edit
  end



  def _breadcrumb_from_path(path)

    cur_path  = nil
    bread = [{ name: @wiki,
               url: url_for(action: :show, wiki:@wiki, path: '/'),
               ico: 'fa-home',
             }]

    path.split('/').each do |part|
      if cur_path
        cur_path +=  '/' + part
      else
        cur_path = part
      end
      #log("wiki (#{@wiki}) is main #{ @wiki.to_s == 'main' ? 'yes' : 'no'}")
      url = if @wiki.to_s == 'main'
                 wiki_main_path(path: cur_path)
            else
                 url_for(action: :show, wiki:@wiki, path: cur_path)
            end
      bread.push({
                  name: part.capitalize.gsub(/_/, ' '),
                  #url: url_for(action: :show, wiki:@wiki, path: cur_path),
                  url: url
                  #url: wiki_main_path(path: cur_path),
                })
    end
    if bread.size > 0
      bread[-1][:active] = true
    end
    @breadcrumb = [ bread ]
  end

  # parse @text
  # *`@text` is parsed wiki
  def _parse
    parser = _get_parser
    parser.at_callback = Proc.new do |key,env|
      case key
        when 'csrf'
          env['nocache'] = '1'
          form_authenticity_token.to_s
        when 'page_version'
          @version
        when 'url_for_root'
          url_for(:root)
        else nil
      end
    end


    env = parser.env
    return {} if env.nil?

    #log("Text #{@text}")
    base_url = url_for(action: :show, wiki:@wiki, path: @path)
    html = parser.to_html(@text, base_url)
    notoc = env.at('notoc', false)
    toc  = nil
    toc = parser.make_toc_html  if ! notoc && parser.headings.size > 3

    return {
      html:             html,
      toc:              toc,
      headings:         parser.headings,
      tep_index:        env.at('tep_index', false),
      wide_display:     env.at('wide_display', false),
      foto_gallery:     env.at('foto_gallery', false),
      background_image: env.at('background_image', nil),
      redirect_to:      env.at('redirect_to', false),
      nocache:          env.at('nocache', false),
    }
  end

  # clear all cache
  def _cache_clear
    return if ! Rails.configuration.wiki_do_cache_parse
    log "cache: clear all"
    Rails.cache.clear
  end

  # delete one file from cache
  # @param version sha256 hash version (git oid) of file
  def _cache_delete(version)
    log "cache: clear #{version}"
    return if ! Rails.configuration.wiki_do_cache_parse
    Rails.cache.delete version
  end

  # try find in cache, or parse, and then store in cache
  def _cached_or_parse_and_cache

    if ! Rails.configuration.wiki_do_cache_parse
      log "no cache: global conf"
      return _parse
    end
    if ! @giwi.cache?
      log "no cache: this giwi no caching"
      return _parse
    end
    if ! @version
      log "no cache: no version"
      return _parse
    end

    cached = Rails.cache.read @version

    # we have in cache
    if cached
      log "chached #{@path}"
      return cached
    end

    # no in cache parse and store in cache
    ret = _parse
    if ! ret[:nocache]
      #  do not cache if page includes more dynamic (calendar, active forms, so on..)
      log "caching:#{@path}"
      Rails.cache.write @version, ret
    else
      log "parsed but:nocache set:#{@path}"
    end
    return ret
  end

end

