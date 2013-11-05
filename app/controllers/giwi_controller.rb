# encoding: utf-8

require 'trac-wiki'
require 'iconv'

class GiwiController < ApplicationController
  authorize_resource :class => false
  include SosnaHelper

  def show

    @wiki = params[:wiki] || 'main'
    @path = params[:path]
    @edit = params[:edit] || false
    @ls   = params[:ls]
    @part = false
    fmt = params[:format]

    return redirect_to path: 'index' if ! @path
    return _handle_ls if @ls
    return _handle_edit if @edit
    return _handle_raw_file("#{@path}.#{fmt}", fmt) if %w(png jpg jpeg gif).include? fmt

    @text, @version = Giwi.get_page @wiki, @path

    return _create_new_page_text if ! @text

    base = url_for(action: :show, wiki: @wiki)
    parser = TracWiki.parser(@text, base: base, math: true, merge: true, edit_heading: true, id_from_heading: true, id_translit: true, no_escape: true)
    @html = parser.to_html
    @headings = parser.headings

    @editable = true

    if parser.headings.size > 3
      @toc = parser.make_toc_html
    end
  end

  def _handle_raw_file(path, fmt)
    @raw, @version = Giwi.get_page @wiki, path
    send_data @raw, :type => fmt, :disposition => 'inline'
  end

  def update
    @wiki = params[:wiki] || 'main'
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

    status = Giwi.set_page @wiki, @path, text, version, 'autor', sline , eline

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

  def _handle_file_upload( file, wiki, filename)
  end

  def _to_ascii(txt)
      txt.gsub! /\s+/, '_'
      Iconv.iconv('ascii//translit', 'utf-8', txt).join('')
  end

  def _handle_ls
    @files, @dirs, @path = Giwi.get_ls @wiki, @path
    render :ls
  end

  def _handle_edit
    if @edit == 'me'
       # edit whole page
       @text, @version = Giwi.get_page @wiki, @path
       @edit = true
       return
    end

    die "wrong edit value" if @edit !~  /^\d+$/

    # want to edit only one chapter
    @part = @edit.to_i

    text, @version = Giwi.get_page @wiki, @path
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

end

