# encoding: utf-8
require 'grit'
require 'pp'
require 'diff3'

class Giwi

  SETPAGE_OK = 0
  SETPAGE_MERGE_OK = 1
  SETPAGE_MERGE_COLLISONS = 2
  SETPAGE_MERGE_DIFF = 2
  attr_accessor :repo
  attr_accessor :name
  attr_accessor :nogit
  attr_accessor :path
  attr_accessor :url
  attr_accessor :read
  attr_accessor :update
  attr_accessor :ext
  @ext = ""

  mattr_accessor :giwis
  @@giwis = {}

  # class methods
  def self.setup
    config = yield self
    config.each do |wiki, opts|
      wiki = wiki.to_sym
      if opts["nogit"]
        print "giki setup: #{wiki} (GiwiNoGit)\n";
        @@giwis[wiki] = GiwiNoGit.new(wiki, opts)
      else
        print "giki setup: #{wiki} (Giwi)\n";
        @@giwis[wiki] = Giwi.new(wiki, opts)
      end
    end

  end
  def self.auth_name wiki
     "giwi_#{wiki}".to_sym
  end

  def self.get_giwi(wiki_name)
    @@giwis[wiki_name.to_sym]
  end

  # class constructor
  def initialize(wiki_name, options)
    @ext = ''
    options.each_pair {|k,v| send("#{k}=", v) }
    @name = wiki_name.to_sym
    @repo = Grit::Repo.new(@path) if ! @nogit
  end

  # public methods (api)

  def get_page(path, raw = false)
    path += @ext if ! raw
    head = @repo.commits.first
    tree = head.tree
    blob = tree / path
    return nil if blob.nil?
    return nil if blob.is_a? Grit::Tree
    text = blob.data.force_encoding('utf-8').encode
    return [ text, head.id]
  end


  # r: [ files, -- files in path dir
  #      dirs,  -- dirs in path dir
  #      path, -- normalized path
  #    ] 
  def get_ls(path)
    repo = @repo
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
  def set_page(path, text, commit_id, autor = 'unknown', sline =nil, eline = nil)

    cur_head = nil

    print "commit_id: #{commit_id}\n"
    text_head = @repo.commit(commit_id)
    cur_head = @repo.commits.first
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
           diff = Grit::Commit.diff(@repo, text_blob.id, cur_blob.id).map {|d| d.diff}.join
           newtext = text + "\n= Collision =\n{{{\n#{diff}\n}}}\n"
        end
        text = newtext
      end
    end

    index = Grit::Index.new(@repo)
    index.read_tree(cur_tree.id)
    index.add(path, text)

    if path =~ /\.(wiki|txt)$/
      fstline = text.each_line.first.chomp.strip
      comment = "file: #{path} head: #{fstline}"
    else
      comment = "file: #{path}"
    end
    comment = comment.force_encoding('ASCII-8BIT')

    index.commit(comment,  parents: [cur_head], last_tree: cur_head, head: 'master')
    return status
  end

  private



  # replace in +text_orig+, lines from +sline+ to  +eline+ with +text+
  # first line is 1 
  def _patch_part(text_part, text_orig, sline, eline)
      lines = text_orig.split("\n", -1)
      lines[(sline -1) ..(eline-1)] = text_part.split("\n", -1)
      lines.join("\n")
  end

#  ##### conf
#  def self.get_repo(wiki)
#    @@giwis ||= {}
#    repo =  @@giwis[wiki.to_sym][:repo]
#
#    return repo if repo
#
#    puts "REPO #{wiki}(#{path}) CREATE"
#    path= @@giwis[wiki.to_sym][:path]
#
#    return @@giwis[wiki.to_sym][:repo] = Grit::Repo.new(path)
#  end
# obsolete?
#  def self.update_part text, part
#    head, part, tail = _split_to_parts(text, part)
#    return head + text + tail
#  end
#  def _split_to_parts text, from, to
#    from, to = part.split(/-/,2)
#    from = from.to_i
#    to = to.to_i
#
#    from = 0 if from < 0
#    from = parts.size if from > parts.size
#
#    to = from + 1 if from > to
#    to = parts.size if from > parts.size
#
#    parts = text.split(/\n/);
#    head = parts[0    ... from].join
#    mid  = parts[from ... to].join
#    tail = parts[to   ... parts.size].join
#
#    return head, part, tail
#  end
end

class GiwiNoGit < Giwi
  def get_page(path, raw = false)
    path_fs = File.join(@path, path)
    path_try = path_fs
    path_try += @ext if ! raw
    print "try:#{path_try}, raw:#{raw}\n"
    print "fs:#{path_fs}\n"

    if ! File.exists? path_try
      print "ex:#{File.directory?(path_fs)}\n"
      if File.directory?(path_fs) && ! raw
        path_try = File.join(path_fs, 'index' + @ext)
        print "try2:#{path_try}\n"
        if ! File.exists? path_try
          return ['NOTFOUND', '0.1']
        end
      else
        return ['NOTFOUND', '0.1']
      end
    end

    return [ File.read(path_try),  '0.1']
  end

  def get_ls(path)
    [[], [], path]
  end
end
