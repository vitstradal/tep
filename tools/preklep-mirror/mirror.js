// Zrcadlo projektů překlepu (Overleaf) pro tools/tex2wiki.rb; z překlepu jen čte.
// mongosh skript, běží v kontejneru preklep-mirror (viz install.sh).
const fs = require('fs');
const path = require('path');

const BASE = process.env.BASE || '/mirror';
const DATA = process.env.DATA || '/overleaf';
const RE = new RegExp(process.env.RE || '^(3\\d|4\\d)_|junior_?4|rychlo|template', 'i');
const KEEP = 2;

const start = new Date();
const gen = `gen-${start.getTime()}`;
const stage = path.join(BASE, gen);
const compilesDir = path.join(DATA, 'compiles');
const compiles = fs.existsSync(compilesDir) ? fs.readdirSync(compilesDir) : [];
const missing = [];
let projects = 0;

fs.mkdirSync(stage, { recursive: true });

function write(root, rel, fn) {
  const dest = path.resolve(root, rel);
  if (!dest.startsWith(root + path.sep)) return missing.push(`${rel} (divné jméno)`);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fn(dest);
}

db.projects.find({ name: RE }, { name: 1, rootFolder: 1 }).forEach(p => {
  const pid = p._id.toHexString();
  const root = path.join(stage, p.name.replace(/[\/\\]/g, '_').replace(/^\.+/, '_'));
  projects++;
  const walk = (f, dir) => {
    for (const d of f.docs || []) {
      const lines = (db.docs.findOne({ _id: d._id }, { lines: 1 }) || {}).lines || [];
      write(root, dir + d.name, dest => fs.writeFileSync(dest, lines.join('\n') + '\n'));
    }
    for (const r of f.fileRefs || []) {
      let src = path.join(DATA, 'user_files', `${pid}_${r._id.toHexString()}`);
      if (!fs.existsSync(src)) {
        src = compiles.filter(n => n.startsWith(pid))
                      .map(n => path.join(compilesDir, n, dir + r.name))
                      .find(f => fs.existsSync(f));
      }
      if (src) write(root, dir + r.name, dest => fs.copyFileSync(src, dest));
      else missing.push(`${p.name}/${dir}${r.name}`);
    }
    for (const s of f.folders || []) walk(s, dir + s.name + '/');
  };
  walk(p.rootFolder[0], '');
});

const tmp = path.join(BASE, 'current.new');
fs.rmSync(tmp, { force: true });
fs.symlinkSync(gen, tmp);
fs.renameSync(tmp, path.join(BASE, 'current'));

fs.readdirSync(BASE).filter(n => /^gen-\d+$/.test(n))
  .sort((a, b) => Number(a.slice(4)) - Number(b.slice(4)))
  .slice(0, -KEEP)
  .forEach(n => fs.rmSync(path.join(BASE, n), { recursive: true, force: true }));

const stamp = path.join(BASE, 'stamp');
const msg = `${start.toISOString()} ${projects} projektů` +
  (missing.length ? `, nenalezeno ${missing.length}:\n${missing.join('\n')}` : '') + '\n';
fs.writeFileSync(stamp, msg);
fs.utimesSync(stamp, start, start);
print(msg.trim());
