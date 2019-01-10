# encoding: utf-8

class PrikladyController < ApplicationController
  include ApplicationHelper
  def sklad
    load_config
    kat = params[:kat]
    ob  = params[:ob]
    tit = params[:tit]
    stav = params[:stav]
    nestav = params[:nestav]
    bad = params[:bad]
    @wiki = 'piki'
    @path = 'priklady'
    @giwi = Giwi.get_giwi(@wiki)
    @files, @dirs, @path_dir = Giwi.get_giwi(@wiki).get_ls(@path)
    @files_parsed = []
    @files.each do |file|
       path =  file[:path]
       next if  path !~ /\.wiki$/
       text, blobid = @giwi.get_page(path)
       item = parse_one(text, path)
       next if ! kat.nil?  && item['kategorie'].to_s.index(kat).nil?
       next if ! ob.nil?   && item['obtížnost'].to_s.index(ob).nil?
       next if ! tit.nil?  && item['title'].to_s.index(tit).nil?
       next if ! stav.nil? && item['stav'].to_s.index(stav).nil?
       next if ! nestav.nil? && ! item['stav'].to_s.index(nestav).nil?
       next if ! bad.nil?  && !item['kategorie'].to_s.empty? &&
                              !item['obtížnost'].to_s.empty? &&
                              !item['zadání'].to_s.empty? &&
                              !item['řešení'].to_s.empty? &&
                              !item['stav'].to_s.empty?
       @files_parsed.push(item)
    end
  end

  def parse_one(text, path)
    #item = {:path => path, :text => text}
    item = { 'path' => path }
    kat = part = nil
    #log "text #{text}"
    if ! text.nil?
      text.split(/\r?\n/).each do |line|
        if line =~ /^\*\*([^*]*)\*\*(.*)/
          _kat, _part = $1, $2
          item[kat] = part.strip if kat
          kat, part = _kat, _part
        elsif line =~ /^=+\s*([^=]*)\s*=*/
          item['title'] = $1.strip
        else
          #log "part #{part} line #{line}"
          part = ( part.nil? ? '' :  part + "\n" ) + line
        end
      end
      item[kat] = part.strip if kat
    end
    return item
  end
end
