# encoding: utf-8

class PrikladyController < ApplicationController
  include ApplicationHelper
  def sklad
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
       @files_parsed.push(item)
    end
  end

  def parse_one(text, path)
    #item = {:path => path, :text => text}
    item = { 'path' => path }
    kat = part = nil
    log "text #{text}"
    if ! text.nil?
      text.split(/\r?\n/).each do |line|
        if line =~ /^\*\*([^*]*)\*\*(.*)/
          _kat, _part = $1, $2
          item[kat] = part.strip if kat
          kat, part = _kat, _part
        elsif line =~ /^=+\s*([^=]*)\s*=*/
          item['title'] = $1.strip
        else
          log "part #{part} line #{line}"
          part = ( part.nil? ? '' :  part + "\n" ) + line
        end
      end
      item[kat] = part.strip if kat
    end
    return item
  end
end
