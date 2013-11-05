# encoding: utf-8
require 'grit'
require 'pp'
require 'diff3'

class Giwi

  SETPAGE_OK = 0
  SETPAGE_MERGE_OK = 1
  SETPAGE_MERGE_COLLISONS = 2
  SETPAGE_MERGE_DIFF = 2
  mattr_accessor :wikis
  @@wikis

  def self.setup
        yield self
        @@wikis.each do |wiki,opts|
           path = opts[:path] || opts["path"]
           opts[:repo] = Grit::Repo.new(path)
           opts[:path] = path
        end
  end

  ##### conf
  def self.get_repo(wiki)
    @@wikis ||= {}
    repo =  @@wikis[wiki.to_s][:repo]

    return repo if repo

    puts "REPO #{wiki}(#{path}) CREATE"
    path= @@wikis[wiki.to_sym][:path]

    return @@wikis[wiki.to_sym][:repo] = Grit::Repo.new(path)
  end

  ##### api
  def self.get_page(wiki,path,part = nil)
    repo = get_repo(wiki)
    #print "path:", path, "\
    head = repo.commits.first
    tree = head.tree
    blob = tree / path
    return nil if blob.nil?
    return nil if blob.is_a? Grit::Tree
    text = blob.data.force_encoding('utf-8').encode
    return [ text, head.id]
  end

  def split_to_parts text, from, to
    from, to = part.split(/-/,2)
    from = from.to_i
    to = to.to_i

    from = 0 if from < 0
    from = parts.size if from > parts.size

    to = from + 1 if from > to
    to = parts.size if from > parts.size

    parts = text.split(/\n/);
    head = parts[0    ... from].join
    mid  = parts[from ... to].join
    tail = parts[to   ... parts.size].join

    return head, part, tail
  end

  def self.update_part text, part
    head, part, tail = split_to_parts(text, part)
    return head + text + tail
  end

  def self.get_ls(wiki, path)
    repo = get_repo(wiki)
    head = repo.commits.first
    tree = head.tree

    #strip trailing /
    path.sub! /[\/]*$/, ''

    # find dir
    while !path.empty?
      tdir = tree / path
      break if tdir.is_a?(Grit::Tree)
      # strip last conponent to /
      path.sub! /(^|\/)[^\/]*$/, ''
    end

    if path.empty?
      tdir = tree
    else
      path += '/'
    end
    print "path:", path, "\n"
    print "tdir:", tdir, "\n"

    files = tdir.blobs.map do |b|
            { path: "#{path}#{b.name}", name: b.name, siz: b.size }
    end
    dirs = tdir.trees.map do |t|
            { path: "#{path}#{t.name}", name: t.name}
    end
    if !path.empty?
      dirs.push( { path: path.sub(/(^|\/)[^\/]*\/$/, ''),
                   name: '..'} )
    end

    [files, dirs, path]
  end

  # text_id aka version
  # if text is only part of file, sline, eline specifies which part (lines from sline to eline (including))
  def self.set_page(wiki, path, text, commit_id, autor = 'unknown', sline =nil, eline = nil)

    repo = get_repo(wiki)
    cur_head = nil

    text_head = repo.commit(commit_id)
    cur_head = repo.commits.first
    cur_tree = cur_head.tree
    status = SETPAGE_OK

    if commit_id != ''
      # not new file
      text_tree = text_head.tree
      cur_blob = cur_tree / path
      text_blob = text_tree / path
      text_blob_data = text_blob.data.force_encoding('utf-8')
  
      if ! sline.nil? && ! eline.nil?
        text = _patch_part(text, text_blob_data, sline, eline)
      end
  
  
      if cur_blob.id != text_blob.id
        # collision: try append diff
        status = SETPAGE_MERGE_OK
        lmine = 'me'
        lorig = 'original'
        lyour = 'your-concurent-editor'
        newtext, diff3_status = Diff3.diff3(lmine, text,
                                            lorig, text_blob_data,
                                            lyour, cur_blob.data.force_encoding('utf-8'))
  
        case diff3_status
          when Diff3::MERGE_COLLISONS
           status = SETPAGE_MERGE_COLLISONS
  
          when Diff3::MERGE_FAIL
           # total fall back (never happens)
           status = SETPAGE_MERGE_DIFF
           diff = Grit::Commit.diff(repo, text_blob.id, cur_blob.id).map {|d| d.diff}.join
           newtext = text + "\n= Collision =\n{{{\n#{diff}\n}}}\n"
        end
        text = newtext
      end
    end

    index = Grit::Index.new(repo)
    index.read_tree(cur_tree.id)
    index.add(path, text)

    fstline = text.each_line.first.chomp.strip
    comment = "file: #{path} head: #{fstline}"
    comment = comment.force_encoding('ASCII-8BIT')

    index.commit(comment,  parents: [cur_head], last_tree: cur_head, head: 'master')
    return status
  end

  # replace in +text_orig+, lines from +sline+ to  +eline+ with +text+
  # first line is 1 
  def self._patch_part(text_part, text_orig, sline, eline)
      lines = text_orig.split("\n", -1)
      lines[(sline -1) ..(eline-1)] = text_part.split("\n", -1)
      lines.join("\n")
  end
end
