# encoding: utf-8

require 'trac-wiki'
require 'iconv'
require 'yaml'

class GiwiController < ApplicationController
  include SosnaHelper

  def show

    @wiki = params[:wiki] || 'main'
    @giwi = Giwi.get_giwi(@wiki)
    auth_name = @giwi.auth_name

    authorize! :show, auth_name

    @editable = can? :update, auth_name

    @path = params[:path]
    @edit = params[:edit] || false
    @ls   = params[:ls]
    @part = false

    fmt = params[:format]

    # @wiki, Giwi.can_read?

    return _handle_ls if @ls
    return _handle_raw_file("#{@path}.#{fmt}", fmt) if %w(pdf png jpg jpeg gif).include? fmt
    return redirect_to action: :show, path: @path + 'index',  wiki: @wiki if @path =~ /\/$/
    return redirect_to action: :show, path: 'index',  wiki: @wiki if ! @path

    _breadcrumb_from_path(@path)

    return _handle_edit if @edit

    path_ext = @path + @giwi.ext
    @text, @version = @giwi.get_page(path_ext)

    if ! @text
      path_idx  = @path + '/index'
      return redirect_to(action: :show, wiki: @wiki, path: path_idx) if @giwi.file?(path_idx + @giwi.ext)
      return _create_new_page_text if can? :update, auth_name
      return _not_found
    end
    @path = path_ext


    base = url_for(action: :show, wiki: @wiki)
    parser = TracWiki.parser(_trac_wiki_options(base))
    @html = parser.to_html(@text)
    @headings = parser.headings
    @tep_index = parser.env.nil? ? false : parser.env.at('tep_index', nil).nil? ? false : true

    if @tep_index
      @no_sidebar = true
      #@breadcrumb = nil
    end
    print "tep_index:",  @tep_index


    if parser.headings.size > 3
      @toc = parser.make_toc_html
    end
  end

  def update
    @wiki = params[:wiki] || 'main'
    @giwi = Giwi.get_giwi(@wiki)

    authorize! :update, @giwi.auth_name
    print "af authorize: :update #{@giwi.auth_name}\n"

    @path = params[:path]
    text = params[:text]
    version = params[:version]

    file = params[:file]
    data = params[:data]
    filename = params[:filename]

    return _handle_file_upload(file.read, filename) if file
    return _handle_file_upload(data, filename, false) if data

    pos = params[:pos]

    email = current_user.full_email
    XX fixme pos
    status = @giwi.set_page(@path + @giwi.ext, text, version, email, pos)

    if status !=  Giwi::SETPAGE_OK
      if status ==  Giwi::SETPAGE_MERGE_OK
         add_alert "Pozor: při editaci nastala kolize, ale podařilo se jí automaticky vyřešit"
      elsif status ==  Giwi::SETPAGE_MERGE_COLLISONS
         add_alert "Pozor: při editaci nastala kolize, kolize je vyznačena v textu, editací uveďte soubor do rozumného stavu"
      elsif status ==  Giwi::SETPAGE_MERGE_DIFF
         add_alert "Pozor: při editaci nastala kolize, rozdíl verzí byl připojen na konec souboru"
      else
         add_alert "Pozor: při editaci nastala kolize, a celé se to rozsypalo"
      end
    end

    redirect_to action: :show, wiki: @wiki, path: @path
  end

  private

  def _handle_raw_file(path, fmt)
    @raw, @version = Giwi.get_giwi(@wiki).get_page(path)
    send_data @raw, :type => fmt, :disposition => 'inline'
  end

  def _trac_wiki_options(base)
    { base: base,
       math: true,
       merge: true,
       edit_heading: @editable,
       id_from_heading: true,
       id_translit: true,
       no_escape: true,
       allow_html: true,
       template_handler: self.method(:template_handler),
    }
  end

  def template_handler(tname, env)
    part = 0
    if tname =~ /\A\//
      tname = $'
      part = 1
    end

    template_path = '.template/' + tname + @giwi.ext
    text, _ = @giwi.get_page(template_path)

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

  def _not_found
    @html = 'not found'
  end

  def _handle_file_upload(file, filename, redirect = true)
    if filename =~ /\/$/ || filename == ''
      ori = file.original_filename
      filename += ori
    end

    raise "bad filename #{filename}" if filename =~ /\.\./

    text = file.read
    Rails::logger.fatal("file:#{filename} text.size:#{text.size}, @path: #{@path}");

    flash[:success] ||= []
    flash[:success].push("Soubor #{filename} uložen.")

    email = current_user.full_email
    status = Giwi.get_giwi(@wiki).set_page(filename, text, '', email)
    Rails::logger.fatal("url::#{url_for(action: :show, wiki: @wiki, path: @path, ls: '.')}"); 

    return redirect_to url_for(action: :show, wiki: @wiki, path: @path, ls: '.') if redirect
    render text: 'tnx'
  end

  def _to_ascii(txt)
      txt.gsub! /\s+/, '_'
      Iconv.iconv('ascii//translit', 'utf-8', txt).join('')
  end

  def _handle_ls
    @files, @dirs, @path_dir = Giwi.get_giwi(@wiki).get_ls(@path)
    render :ls
  end

  def _handle_edit

    @text, @version = @giwi.get_page(@path + @giwi.ext)

    base = url_for(action: :show, wiki: @wiki)
    parser = TracWiki.parser(_trac_wiki_options(base))
    if @text
      parser.to_html(@text)
      @used_templates = parser.used_templates
      pp "used templates", @used_templates
    end

    if @edit == 'me'
       @edit = true
       return
    end

    die "wrong edit value" if @edit !~  /^\d+$/

    # want to edit only one chapter
    @part = @edit.to_i

    if text
     # parser = TracWiki.parser(math: true, merge: true,  no_escape: true, )
      heading = parser.headings[@part]
      if heading
        # edit only selected part (from @sline to @eline)
        @text = text.split("\n").values_at(heading[:sline]-1 .. heading[:eline]-1).join("\n")
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
      bread.push({
                  name: part.capitalize.gsub(/_/, ' '),
                  url: url_for(action: :show, wiki:@wiki, path: cur_path),
                })
    end
    if bread.size > 0 
      bread[-1][:active] = true
    end
    @breadcrumb = [ bread ] 
  end

end

