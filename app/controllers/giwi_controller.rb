# encoding: utf-8

require 'trac-wiki'

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
      @ls = Giwi.get_ls @wiki, @path
      return render :ls
    end

    @text = Giwi.get_page @wiki, @path
    @title = @path.capitalize
    pp "giwiwiki", Giwi.wikis
    if ! @text
      @text = 'new page'
      @edit = true
    end
    @html = TracWiki.render(@text)
    @editable = true

    # if not exists bla bla bla

  end

  def update
    wiki = params[:wiki] || 'main'
    path = params[:path]
    text = params[:text]
    Giwi.set_page wiki, path, text
    redirect_to action: :show, wiki: wiki, path: path
  end
end

