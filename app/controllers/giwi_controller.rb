# encoding: utf-8

require 'trac-wiki'
require 'iconv'

class GiwiController < ApplicationController
  authorize_resource :class => false
  def show
    @wiki = params[:wiki] || 'main'
    @path = params[:path]
    @edit = params[:edit]
    @ls   = params[:ls]

    if ! @path
      return redirect_to path: 'index'
    end

    if @ls
      @files, @dirs, @path = Giwi.get_ls @wiki, @path
      return render :ls
    end

    @text, @version = Giwi.get_page @wiki, @path
    @title = @path.capitalize
    pp "giwiwiki", Giwi.wikis
    if ! @text
      title = @path.split(/\//).last
      @text = "= #{title.capitalize} =\n\n"
      @path = _to_ascii(@path)
      @edit = true
    end
    @html = TracWiki.render(@text, math: true, merge: true, no_escape: true)
    @editable = true

    # if not exists bla bla bla

  end


  def update
    wiki = params[:wiki] || 'main'
    path = params[:path]
    text = params[:text]
    version = params[:version]
    status = Giwi.set_page wiki, path, text, version

    if status !=  Giwi::SETPAGE_OK
      if status ==  Giwi::SETPAGE_MERGE_OK
         flash[:errors] = {Pozor: "při editaci nastala kolize, ale podařilo se jí automaticky vyřešit"}
      elsif status ==  Giwi::SETPAGE_MERGE_COLLISONS
         flash[:errors] = {Pozor: "při editaci nastala kolize, kolize je vyznačena v textu, editací uveďte soubor do rozumného stavu"}
      elsif status ==  Giwi::SETPAGE_MERGE_DIFF
         flash[:errors] = {Pozor: "při editaci nastala kolize, rozdíl verzí byl připojen na konec souboru"}
      else
         flash[:errors] = {Pozor: "při editaci nastala kolize, a celé se to rozsypalo"}
      end
    end

    redirect_to action: :show, wiki: wiki, path: path
  end

  def _to_ascii(txt)
      txt.gsub! /\s+/, '_'
      Iconv.iconv('ascii//translit', 'utf-8', txt).join('')
  end
end

