require 'grit'
require 'pp'

class Giwi

  mattr_accessor :wikis
  @@wikis

  def self.setup
        yield self
        @@wikis.each do |wiki,opts|
           path = opts[:path] || opts["path"]
           opts[:repo] = Grit::Repo.new(path)
           opts[:path] = path
        end
        #pp @@wikis
        @@wikis.freeze

  end

  ##### conf
  def self.get_repo(wiki)
    repo =  @@wikis[wiki.to_s][:repo]
    if repo
      puts "YES REPO"
      return repo
    end

    puts "NO REPO!"
    path= @@wikis[wiki.to_sym][:path]
    return @@wikis[wiki.to_sym][:repo] = Grit::Repo.new(path)
  end

  ##### api
  def self.get_page(wiki,path,part = nil)
    repo = get_repo(wiki)
    print "path:", path
    head = repo.commits.first
    tree = head.tree
    blob = tree / path
    return nil if blob.nil?
    return nil if blob.is_a? Grit::Tree
    text = blob.data.force_encoding('utf-8').encode
    commit_id = head.id
    return [ text, commit_id]
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

  # commit_id aka version
  def self.set_page(wiki, path, text, commit_id, part =nil)
    fstline = text.each_line.first.chomp.strip

    repo = get_repo(wiki)
    head = repo.commits.first

    collision = false

    if head.id != commit_id
      diff = Grit::Commit.diff(repo, commit_id, head.id)
      difftext = diff.map {|d| d.diff}.join('-')
      text += "\n= Collision =\n{{{\n#{difftext}\n}}}\n"
      collision = true
    end

    tree = head.tree
    index = Grit::Index.new(repo)
    index.read_tree(tree.id)
    index.add(path, text)

    comment = "file: #{path} head: #{fstline}"
    comment = comment.force_encoding('ASCII-8BIT')

    index.commit(comment,  parents: [head], last_tree: head, head: 'master')

    return collision
  end

end
