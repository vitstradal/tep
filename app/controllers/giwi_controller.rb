# encoding: utf-8

require 'trac-wiki'
require 'iconv'

class GiwiController < ApplicationController
  include SosnaHelper

  def show

    @wiki = params[:wiki] || 'main'
    print "wiki:#{@wiki}\n"

    authorize! :show, Giwi.auth_name(@wiki)

    @editable = can? :update,  Giwi.auth_name(@wiki)

    @path = params[:path]
    @edit = params[:edit] || false
    @ls   = params[:ls]
    @part = false
    fmt = params[:format]

    # @wiki, Giwi.can_read?
    print "path:#{@path}\n"

    return redirect_to action: :show, path: 'index',  wiki: @wiki if ! @path
    return _handle_ls if @ls
    return _handle_raw_file("#{@path}.#{fmt}", fmt) if %w(png jpg jpeg gif).include? fmt
    return redirect_to action: :show, path: @path + 'index',  wiki: @wiki if @path =~ /\/$/

    _breadcrumb_from_path(@path)

    return _handle_edit if @edit

    @text, @version = Giwi.get_giwi(@wiki).get_page(@path)

    return _create_new_page_text if ! @text

    base = url_for(action: :show, wiki: @wiki)
    parser = TracWiki.parser(@text, _trac_wiki_options(base))
    @html = parser.to_html
    @headings = parser.headings


    if parser.headings.size > 3
      @toc = parser.make_toc_html
    end
  end


  def update
    @wiki = params[:wiki] || 'main'

    authorize! :update, Giwi.auth_name(@wiki)
    print "af authorize: :update #{Giwi.auth_name(@wiki)}\n"

    @path = params[:path]
    text = params[:text]
    version = params[:version]

    file = params[:file]
    filename = params[:filename]

    return _handle_file_upload(wiki, path, file, filename) if file

    sline = params[:sline]
    eline = params[:eline]

    sline = sline.to_i if ! sline.nil?
    eline = eline.to_i if ! eline.nil?

    status = Giwi.get_giwi(@wiki).set_page(@path, text, version, 'autor', sline , eline)

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
    @raw, @version = Giwi.get_giwi(@wiki).get_page(path, true)
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
       raw_html: true,
       template_handler: self.method(:template_handler)
    }
  end


  def template_handler(tname, env)
    template_path = '.template/' + tname
    text, _ = Giwi.get_giwi(@wiki).get_page(template_path, true )
    return nil if text.nil?
    text
  end


  def _handle_file_upload( file, wiki, filename)
  end

  def _to_ascii(txt)
      txt.gsub! /\s+/, '_'
      Iconv.iconv('ascii//translit', 'utf-8', txt).join('')
  end

  def _handle_ls
    @files, @dirs, @path = Giwi.get_giwi(@wiki).get_ls(@path)
    render :ls
  end

  def _handle_edit
    if @edit == 'me'
       # edit whole page
       @text, @version = Giwi.get_giwi(@wiki).get_page(@path)
       @edit = true
       return
    end

    die "wrong edit value" if @edit !~  /^\d+$/

    # want to edit only one chapter
    @part = @edit.to_i

    text, @version = Giwi.get_giwi(@wiki).get_page(@path)
    print "part:#{@part}\n"

    if text
      parser = TracWiki.parser(text, math: true, merge: true,  no_escape: true)
      parser.to_html
      heading = parser.headings[@part]
      print "headigns", pp(parser.headings)
      if heading
        # edit only selected part (from @sline to @eline)
        @text = text.split("\n").values_at(heading[:sline]-1 .. heading[:eline]-1).join("\n")
        @sline = heading[:sline]
        @eline = heading[:eline]
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
             }]

    path.split('/').each do |part|
      if cur_path 
        cur_path +=  '/' + part
      else
        cur_path = part
      end
      bread.push({
                  name: part,
                  url: url_for(action: :show, wiki:@wiki, path: cur_path),
                })
    end
    if bread.size > 0 
      bread[-1][:active] = true
    end
    @breadcrumb = [ bread ] 
  end

end

