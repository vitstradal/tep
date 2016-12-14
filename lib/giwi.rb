# encoding: utf-8
#require 'grit'
require 'rugged'
require 'pp'
require 'diff3'

class Giwi

  SETPAGE_OK = 0
  SETPAGE_MERGE_OK = 1
  SETPAGE_MERGE_COLLISONS = 2
  SETPAGE_MERGE_DIFF = 3
  SETPAGE_ERROR = 4
  attr_accessor :repo
  attr_accessor :name
  attr_accessor :nogit
  attr_accessor :bare
  attr_accessor :branch
  attr_accessor :path
  attr_accessor :url
  attr_accessor :read
  attr_accessor :update
  attr_accessor :ext
  attr_accessor :help_link
  attr_accessor :templates
  @ext = ""

  mattr_accessor :giwis
  @@giwis = {}

  # class methods
  def self.setup
    config = yield self
    config.each do |wiki, opts|
      wiki = wiki.to_sym
      if opts["nogit"]
        #print "giki setup: #{wiki} (GiwiNoGit)\n";
        @@giwis[wiki] = GiwiNoGit.new(wiki, opts)
      else
        #print "giki setup: #{wiki} (Giwi)\n";
        @@giwis[wiki] = Giwi.new(wiki, opts)
      end
    end

  end
  def self.auth_name wiki
     "giwi_#{wiki}".to_sym
  end
  def auth_name
     "giwi_#{self.name}".to_sym
  end

  def self.get_giwi(wiki_name)
    @@giwis[wiki_name.to_sym]
  end

  # class constructor
  def initialize(wiki_name, options)
    @bare = true
    @branch = 'master'
    @ext = ''
    options.each_pair {|k,v| send("#{k}=", v) }
    @name = wiki_name.to_sym
    #@repo = Grit::Repo.new(@path, is_bare: @bare) if ! @nogit
    @repo = Rugged::Repository.new(@path) if ! @nogit
  end

  # public methods (api)

  # try (in that order):
  # path
  # path.wiki
  # path/index.wiki
  def get_page(path, raw = false)

    blob = _get_path_obj(path)

    return nil if blob.nil? || blob.type != :blob

    text = blob.content
    text = text.force_encoding('utf-8').encode

    return [ text, blob.oid]
  end

  def cache_killer?
    @name.to_sym == @templates.to_sym
  end

  def cache?
    if @nogit
        false
    else
        true
    end 
  end


  # r: [ files, -- files in path dir
  #      dirs,  -- dirs in path dir
  #      path, -- normalized path
  #    ]
  def get_ls(path)

    # find dir
    path ||= ''
    while !path.empty?
      #print "B1#{path}\n"
      tdir_h = _get_path_obj_h(path)
      #print "B2\n"
      break if !tdir_h.nil? && tdir_h[:type] == :tree
      # strip last conponent to /
      path.sub! /(^|\/)[^\/]*$/, ''
    end

    if path.empty?
      #print "B22\n"
      tdir = _get_path_obj('')
      #print "B23#{pp(tdir)}\n"
    else
      #print "B23#{pp(tdir_h)}\n"
      tdir = @repo.lookup tdir_h[:oid]
      path += '/'
    end

    files = []
    dirs = []

    tdir.each_blob do |b|
            #pp b
            files.push({ path: "#{path}#{b[:name]}", name: b[:name], siz: 0 })
    end
    tdir.each_tree do |t|
            dirs.push({ path: "#{path}#{t[:name]}", name: t[:name]})
    end

    if !path.empty?
      dirs.push( { path: path.sub(/(^|\/)[^\/]*\/$/, ''),
                   name: '..'} )
    end
    #pp [files, dirs, path]
    return [files, dirs, path]
  end

  def file?(path)
    st = stat(path)
    return false if st.nil?
    return ! st[:isdir]
  end
  def dir?(path)
    st = stat(path)
    return false if st.nil?
    return st[:isdir]
  end
  def stat(path)
    obj = _get_path_obj path
    return nil if  obj.nil?
    return { :isdir => obj.type == :tree}
  end

  # text_id aka version
  # if text is only part of file, sline, eline specifies which part (lines from sline to eline (including))
  def set_page(path, text, oid, email = 'unknown', pos=nil)

    status = SETPAGE_OK

    if oid != ''

      cur_blob  = _get_path_obj(path)

      text_blob = @repo.lookup oid
      raise "no path #{path}" if text_blob.type != :blob

      text_blob_data = text_blob.content.force_encoding('utf-8')

      if ! pos.nil?
        text = _patch_part(text, text_blob_data, pos)
      end

      if cur_blob.oid != text_blob.oid
        # collision: try append diff
        status = SETPAGE_MERGE_OK
        lmine = 'me'
        lorig = 'original'
        lyour = 'your-concurent-editor'

        cur_blob_data = cur_blob.content.force_encoding('utf-8')

        #print "cb:#{cur_blob_data.sub(/[\n\r]/s, '-')}, text:#{text_blob_data.sub(/[\n\r]/s, '-')}\n"

        newtext, diff3_status = Diff3.diff3(lmine, text,
                                            lorig, text_blob_data,
                                            lyour, cur_blob_data)
        case diff3_status
          when Diff3::MERGE_COLLISONS
           status = SETPAGE_MERGE_COLLISONS

          when Diff3::MERGE_FAIL
           # total fall back (never happens)
           status = SETPAGE_MERGE_DIFF
           diff = "FÜX:ME"
           # diff Grit::Commit.diff(@repo, text_blob.id, cur_blob.id).map {|d| d.diff}.join #FIXME
           newtext = text + "\n= Collision =\n{{{\n#{diff}\n}}}\n"
        end
        text = newtext
      end
    end

    index = @repo.index
    text_oid = @repo.write(text, :blob);
    cur_tree = _get_cur_tree
    #pp("repo.head.target.tree",repo.head.target.tree )
    index.read_tree(cur_tree)
    #index.read_tree(repo.head.target.tree )
    index.add(:path => path, :oid => text_oid, :mode  => 0100644 )

    if path =~ /\.(wiki|txt)$/
      fstline = text.each_line.first.chomp.strip
      comment = "#{fstline}"
    else
      comment = "file: #{path}"
    end
    comment = comment.force_encoding('ASCII-8BIT')

    name = ''
    name, email = [$1, $2] if email =~ /^(.*)\s*<(\S*@\S*)>$/

    options = {
        :tree => index.write_tree(@repo),
        :author =>  { :email => email,
                      :time  => Time.now,
                      :name => name,
                   },
        :message => comment,
        :parents => [ _get_cur_target ].compact,
        :update_ref => 'refs/heads/' + @branch,
    }
        #:parents => [ repo.head.target ].compact,
    Rugged::Commit.create(@repo, options)
    #Rails::logger.fatal("options:#{pp(options)}");
    _post_commit_hook()
    return status
  end

  def _post_commit_hook
    hook_path = File.join(@path, 'hooks/post-receive')
    if File.executable?(hook_path)
      Rails::logger.fatal("executing #{hook_path}")
      system(hook_path)
    else
      Rails::logger.fatal("not executing #{hook_path}")
    end
  end

  def get_history(opts = {})
    commit =  @repo.head.target
    history = []
    count = 1
    while commit.parents.size > 0 && count < 500
      parent = commit.parents[0]
      diff = parent.diff(commit)

      files = []
      diff.deltas.each do |d|
        files.push({ :new_file =>  d.new_file[:path].force_encoding('utf-8').encode,
                     :old_file => d.old_file[:path].force_encoding('utf-8').encode,
                     :binary =>  d.binary
                   })
      end

      message = commit.message.force_encoding('utf-8').encode
      author = commit.author
      email = author[:email].force_encoding('utf-8').encode
      name = author[:name].force_encoding('utf-8').encode
      time = author[:time]

      history.push({ :message => message, :commit => commit.oid, :files =>  files , :author =>  { :email => email, :name => name, :time => time} })
      commit = parent
      count += 1
    end
    return history
  end

  def get_diff(commit_oid)
    commit =  @repo.lookup(commit_oid)
    parent = commit.parents[0]
    diff = parent.diff(commit)
    #pp diff.deltas
    return diff.each_line.map do |l|
            { content: l.content.force_encoding('utf-8').encode, 
              line_origin: l.line_origin,
            }
    end
  end

  private

  def _get_cur_target
    branch = @repo.branches[@branch]
    return nil if branch.nil?
    return branch.target

  end

  def _get_cur_tree

    branch = @repo.branches[@branch]
    return nil if branch.nil?

    return branch.target.tree

  end

  def _get_path_obj_h(path = '')
    #print "A1#{path}\n";

    tree = _get_cur_tree
    return nil if tree.nil?

    # FIXME
    return {:oid => tree.oid, :type => :tree } if path.empty?

    begin
      obj_h = tree.path(path)
    rescue
      obj_h = nil
    end
    return obj_h
  end

  def _get_path_obj(path)

    obj_h = _get_path_obj_h(path)
    return nil if obj_h.nil?
    #print "obj.oid:#{obj_h[:oid]}\n"

    obj = repo.lookup obj_h[:oid]
    return obj
  end


  # in +text_orig+ replace place defined by +pos+  with text +part+
  # +pos+ in form '3.0-44.20' "from start of line 3 to line 44 char 20"
  # +pos+ in form '3-44' "from start of line 3 to start line 44 (inc \n)"
  # +pos+ in form '3.4' "insert at line 3 after char 4"
  # first line is 1
  # 1-2 means first line  including '\n'
  def _patch_part(part, text_orig, pos)

      if pos =~ /\A(\d+)(?:\.(\d+))?(?:-(\d+)(?:\.(\d+))?)?\Z/

        bline, eline = $1.to_i-1,  ($3||$1).to_i-1
        boff, eoff = ($2||0).to_i, ($4||$2||0).to_i

        lines = text_orig.split("\n", -1)

        # zacatek pocatecni radky
        prefix  = ''
        if boff > 0
          prefix =  lines[bline][0 .. boff-1]
          prefix ||= ''
        end

        # konec koncove radky 
        endline = lines[eline] || ''
        postfix = endline[eoff .. -1] || ''

        #Rails::logger.fatal("pos(#{pos}) bline(#{bline}) bof(#{boff}) bofzero(#{boff==0?1:0}) eline(#{eline}) eoff(#{eoff}) pre(#{prefix}) post(#{post_part})")

        lines[bline .. eline] = prefix + part + postfix
        lines.join("\n")
      else
        raise "bad pos (#{pos})"
      end
  end
end

class GiwiNoGit < Giwi
  def stat(path)
    path_fs = File.join(@path, path)
    #print "fs: #{path_fs}\n"
    return nil if ! File.exists?(path_fs)
    st = File.stat(path_fs)
    return nil if st.nil?
    return { :isdir => st.directory? }
  end

  def get_page(path, raw = false)
    path_fs = File.join(@path, path)
    return nil if ! File.exists? path_fs
    return [ File.read(path_fs),  false]
  end

  def get_ls(path)
    while !path.empty?
      break if File.directory?(File.join(@path, path))
      path.sub! /(^|\/)[^\/]*$/, ''
    end
    dirs = []
    files = []
    dir = File.join(@path, path)
    Dir.entries(dir).each do |entry|
      next if entry =~ /^\.$/
      full = "#{path}/#{entry}"
      fs_full = File.join(dir, entry);
      files.push({path: full, name:entry, size:File.size(fs_full)})  if File.file?(fs_full)
      dirs.push({path: full, name:entry})  if File.directory?(fs_full)
    end
    [files, dirs, path]
  end

  def set_page(path, text, commit_id, email = 'unknown', pos = nil)
    path_fs = File.join(@path, path)

    if ! pos.nil?
      begin
        text_old = File.read(path_fs)
        text = _patch_part(text, text_old, pos)
      rescue
        return SETPAGE_ERROR
      end
    end
    File.write(path_fs, text)
    return SETPAGE_OK
  end

  def get_history
    []
  end

  def get_diff(path, old_ver, new_ver)

    []
  end

end
