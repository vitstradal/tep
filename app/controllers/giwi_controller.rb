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
      @text = "= #{@path} =\n\n"
      @path = _to_ascii(@path)
      @edit = true
    end
    @html = TracWiki.render(@text, math: true, no_escape: true)
    @editable = true

    # if not exists bla bla bla

  end


  def update
    wiki = params[:wiki] || 'main'
    path = params[:path]
    text = params[:text]
    version = params[:version]
    collision = Giwi.set_page wiki, path, text, version

    if collision
       flash[:errors] = {kolize: "při editaci nastala kolize, rozdíl verzí byl připojen na konec souboru"}
    end

    redirect_to action: :show, wiki: wiki, path: path
  end

  def _to_ascii(txt)
      txt.gsub! /\s+/, '_'
      Iconv.iconv('ascii//translit', 'utf-8', txt).join('')
  end
end

