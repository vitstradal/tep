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
        pp @@wikis
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

#  def self.add_wiki(wiki, path, opts = {})
#    if is_a? Hash
#      opts = path
#    else
#      opts[:path] = path
#    end
#    @@wikis ||= {}
#    @@wikis[wiki.to_sym] = opts
#  end

  ##### api
  def self.get_page(wiki,path,part = nil)
    repo = get_repo(wiki)
    head = repo.commits.first
    tree = head.tree
    blob = tree / path
    return nil if blob.nil?
    return nil if blob.is_a? Grit::Tree
    return blob.data
  end

  def self.get_ls(wiki, path)
    repo = get_repo(wiki)
    head = repo.commits.first
    tree = head.tree

    return tree.blobs.map {|b| b.name}
  end

  def self.set_page(wiki, path, text, part =nil)
    comm = text.each_line.first.chomp.strip

    repo = get_repo(wiki)
    head = repo.commits.first
    tree = head.tree

    index = Grit::Index.new(repo)
    index.read_tree(tree.id)
    index.add(path, text)
    #index.commit("Automatic commit", [head])
    #index.commit("Automatic commit")
    index.commit("Automatic commit '#{comm}'", parents: [head], last_tree: head, head: 'master')
    return 1
  end

end
