#!/usr/bin/env ruby
##
# preklep-mirror.rb — zrcadlí projekty z preklepu (Overleaf) do adresáře,
# aby se z nich daly generovat wiki stránky (tools/tex2wiki.rb). Z preklepu jen čte.
#
# Použití (root na pikomatu):
#   preklep-mirror.rb [REGEX]               vypíše odpovídající projekty
#   preklep-mirror.rb --export [REGEX]      zrcadlo do OUT/<jméno projektu>/
#                                           (staví vedle a pak vymění celé OUT)
#
# REGEX vybírá podle jména projektu (bez ohledu na velikost písmen).
require 'json'
require 'fileutils'
require 'open3'

MONGO = ENV.fetch('MONGO', 'mongo')
DATA  = ENV.fetch('OVERLEAF_DATA', '/home/www/overleaf/data/overleaf/data')
OUT   = ENV.fetch('OUT', '/home/pikomat/preklep-mirror')
GROUP = ENV.fetch('GROUP', 'pikomat')

export = ARGV.delete('--export')
regex  = ARGV[0] || '^(3\d|4\d)_|junior_?4|rychlo|template'

js = <<~JS
  const re = new RegExp(process.env.RE, 'i');
  const full = process.env.EXPORT === '1';
  db.projects.find({name: re}, {name: 1, lastUpdated: 1, rootFolder: 1}).sort({name: 1}).forEach(p => {
    const walk = (f, dir) => {
      for (const d of f.docs || []) {
        const o = {pid: p._id.toHexString(), project: p.name, path: dir + d.name, kind: 'doc'};
        if (full) o.lines = (db.docs.findOne({_id: d._id}, {lines: 1}) || {}).lines || [];
        print(JSON.stringify(o));
      }
      for (const r of f.fileRefs || []) print(JSON.stringify({pid: p._id.toHexString(), project: p.name, path: dir + r.name, kind: 'file', id: r._id.toHexString(), hash: r.hash}));
      for (const s of f.folders || []) walk(s, dir + s.name + '/');
    };
    print(JSON.stringify({pid: p._id.toHexString(), project: p.name, kind: 'project', updated: p.lastUpdated}));
    walk(p.rootFolder[0], '');
  });
JS

out, err, st = Open3.capture3('docker', 'exec', '-e', "RE=#{regex}", '-e', "EXPORT=#{export ? 1 : 0}",
                              MONGO, 'mongosh', '--quiet', 'sharelatex', '--eval', js)
abort "mongosh selhal: #{err}" unless st.success?
items = out.lines.map { |l| JSON.parse(l) }

unless export
  items.select { |i| i['kind'] == 'project' }.each do |p|
    n = items.count { |i| i['pid'] == p['pid'] && i['kind'] != 'project' }
    puts format('%s  %-10s  %3d souborů  %s', p['pid'], p['updated'].to_s[0, 10], n, p['project'])
  end
  puts "\n(nic nezapsáno; --export zapíše do #{OUT})"
  exit
end

missing = []
stage = "#{OUT}.new"
FileUtils.rm_rf(stage)
items.each do |i|
  next if i['kind'] == 'project'
  dest = File.join(stage, i['project'].tr('/', '_'), i['path'])
  FileUtils.mkdir_p(File.dirname(dest))
  if i['kind'] == 'doc'
    File.write(dest, i['lines'].join("\n") + "\n")
  else
    src = File.join(DATA, 'user_files', "#{i['pid']}_#{i['id']}")
    src = Dir.glob(File.join(DATA, 'compiles', "#{i['pid']}*", i['path'])).first unless File.exist?(src)
    src ? FileUtils.cp(src, dest) : missing << "#{i['project']}/#{i['path']}"
  end
end
system('chgrp', '-R', GROUP, stage) && system('chmod', '-R', 'g+rwX,o+rX', stage)
FileUtils.rm_rf("#{OUT}.old")
File.rename(OUT, "#{OUT}.old") if File.exist?(OUT)
File.rename(stage, OUT)
FileUtils.rm_rf("#{OUT}.old")
puts "zapsáno do #{OUT}: #{items.count { |i| i['kind'] == 'project' }} projektů"
puts "nenalezené binární soubory (#{missing.size}):", missing unless missing.empty?
