#!/usr/bin/env python3
##
# pikomat-zaloha.py — záloha pikomatu (pouštět pod rootem na pikomatu)
#
# Zálohuje (co přesně říká konfigurák /etc/pikomat-zaloha.conf, TOML):
#   1. PostgreSQL: databáze ze zadaných clusterů — per-DB pg_dump -Fc
#      (zstd u pg_dump >= 16) + globals (role/tablespaces) per cluster.
#   2. rsync snapshoty adresářů (default /home/www, /home/pikomat)
#      s --link-dest: každý den vlastní adresář, nezměněné soubory
#      jsou hardlinky (platí se jen za rozdíly).
#
# Cíl NENÍ offsite záloha — proti požáru/krádeži nechrání; offsite
# řešit zvlášť (restic/rclone jinam).
#
# POZOR: overleaf (preklep) drží projekty v MongoDB (docker) — file-level
# kopie běžícího monga nemusí být konzistentní. Konzistentní dump:
# docker exec <mongo> mongodump --archive (po migraci na afterleaf odpadá).
#
# Použití:  pikomat-zaloha.py [--dry-run] [--list] [--config SOUBOR]
#
# Instalace (root):
#   install -m 755 pikomat-zaloha.py /usr/local/sbin/pikomat-zaloha.py
#   install -m 644 pikomat-zaloha.conf /etc/pikomat-zaloha.conf
#   install -m 644 pikomat-zaloha.service pikomat-zaloha.timer /etc/systemd/system/
#   systemctl daemon-reload
#   systemctl enable --now pikomat-zaloha.timer
#   # ruční běh: systemctl start pikomat-zaloha; log: journalctl -u pikomat-zaloha
#
# Obnova:
#   pg_restore -p 5432 -U postgres -d <db> --clean pg/<datum>/<db>-5432.dump
#   globals: zstdcat globals-5432.sql.zst | sudo -u postgres psql -p 5432
#   soubory: prostě rsync/cp z www/<datum>/ zpět.

import argparse
import datetime
import fcntl
import glob
import os
import re
import shutil
import subprocess
import sys
import tomllib

CONFIG_DEFAULT = '/etc/pikomat-zaloha.conf'

# hodnoty, které konfigurák nemusí uvádět
DEFAULTS = {
    'zaloha_root': '/home/backup/pikomat',
    'min_volne_gb': 100,       # tvrdá stopka, ať záloha nezaplní disk
    'uchovat_pg_dnu': 14,      # kolik dní držet PG dumpy
    'uchovat_snap': 5,         # kolik denních rsync snapshotů držet
    'clustery': [5432, 5435],  # PG porty
    'zalohuj_db': [],          # whitelist; neprázdný = dumpuj JEN tyto
    'nezalohuj_db': [],        # blacklist; použije se při prázdném whitelistu
    'snapshoty': [],           # [{nazev, zdroj, exclude: [...]}, ...]
}

DNES = datetime.date.today().isoformat()
LOG_FILE = None


def log(*vec):
    radek = '[{}] {}'.format(
        datetime.datetime.now().strftime('%F %T'), ' '.join(str(v) for v in vec))
    print(radek, flush=True)          # stdout → systemd journal
    if LOG_FILE:
        print(radek, file=LOG_FILE, flush=True)


def chyba(*vec):
    log('CHYBA:', *vec)
    sys.exit(1)


def nacti_config(cesta):
    cfg = dict(DEFAULTS)
    try:
        with open(cesta, 'rb') as f:
            cfg.update(tomllib.load(f))
    except FileNotFoundError:
        chyba(f'konfigurák {cesta} neexistuje')
    except tomllib.TOMLDecodeError as e:
        chyba(f'konfigurák {cesta}: {e}')
    neznam = set(cfg) - set(DEFAULTS)
    if neznam:
        chyba(f'konfigurák {cesta}: neznámé klíče {sorted(neznam)}')
    return cfg


def psql(port, dotaz):
    """Výstup psql -At po řádcích (běží jako postgres)."""
    r = subprocess.run(['sudo', '-u', 'postgres', 'psql', '-p', str(port),
                        '-At', '-c', dotaz],
                       capture_output=True, text=True)
    if r.returncode != 0:
        chyba(f'psql :{port}: {r.stderr.strip()}')
    return r.stdout.splitlines()


def pg_bezi(port):
    return subprocess.run(['sudo', '-u', 'postgres', 'pg_isready', '-q',
                           '-p', str(port)]).returncode == 0


def vyber_pg_dump():
    """Nejnovější nainstalovaná binárka; Debianí wrapper by vybral verzi
    default clusteru (15), zstd ale umí až pg_dump >= 16 (komprese je
    klientská, funguje i proti staršímu serveru)."""
    kandidati = sorted(
        (p for p in glob.glob('/usr/lib/postgresql/*/bin/pg_dump')
         if p.split('/')[4].isdigit()),
        key=lambda p: int(p.split('/')[4]))
    binarka = kandidati[-1] if kandidati else 'pg_dump'
    ver = subprocess.run([binarka, '--version'], capture_output=True, text=True)
    verze = int(re.search(r'\d+', ver.stdout).group())
    kompres = '--compress=zstd:6' if verze >= 16 else '--compress=6'
    return binarka, verze, kompres


def volne_gb(cesta):
    return shutil.disk_usage(cesta).free // 2**30


def kontrola_mista(cfg):
    v = volne_gb(cfg['zaloha_root'])
    if v < cfg['min_volne_gb']:
        chyba(f"málo místa ({v} GB < {cfg['min_volne_gb']} GB) — končím")


def zalohuj_pg(cfg, dry):
    if not cfg['clustery']:
        return
    pg_dump, verze, kompres = vyber_pg_dump()
    log(f'pg_dump {pg_dump} (v{verze}), komprese: {kompres}')
    pg_dir = os.path.join(cfg['zaloha_root'], 'pg', DNES)
    os.makedirs(pg_dir, exist_ok=True)

    for port in cfg['clustery']:
        if not pg_bezi(port):
            log(f'pg :{port} neběží — přeskakuji')
            continue
        log(f'pg :{port} — globals')
        if not dry:
            with open(os.path.join(pg_dir, f'globals-{port}.sql.zst'), 'wb') as f:
                dumpall = subprocess.Popen(
                    ['sudo', '-u', 'postgres', 'pg_dumpall', '-p', str(port),
                     '--globals-only'], stdout=subprocess.PIPE)
                zst = subprocess.run(['zstd', '-q'], stdin=dumpall.stdout, stdout=f)
                dumpall.stdout.close()
                if dumpall.wait() != 0 or zst.returncode != 0:
                    chyba(f'globals :{port} selhaly')

        for db in psql(port, 'SELECT datname FROM pg_database WHERE NOT datistemplate'):
            if cfg['zalohuj_db']:
                if db not in cfg['zalohuj_db']:
                    log(f'pg :{port} — {db} přeskočena (není v zalohuj_db)')
                    continue
            elif db in cfg['nezalohuj_db']:
                log(f'pg :{port} — {db} přeskočena (nezalohuj_db)')
                continue
            log(f'pg :{port} — dump {db}')
            if not dry:
                # pg_dump běží jako postgres, do souboru zapisuje root —
                # postgres do zálohy psát nesmí
                with open(os.path.join(pg_dir, f'{db}-{port}.dump'), 'wb') as f:
                    r = subprocess.run(['sudo', '-u', 'postgres', pg_dump,
                                        '-p', str(port), '-Fc', kompres, db],
                                       stdout=f)
                if r.returncode != 0:
                    chyba(f'pg_dump {db}:{port} selhal (rc={r.returncode})')

    # retence: adresáře pojmenované datem, starší než uchovat_pg_dnu pryč
    hranice = datetime.date.today() - datetime.timedelta(days=cfg['uchovat_pg_dnu'])
    for d in sorted(glob.glob(os.path.join(cfg['zaloha_root'], 'pg', '20*'))):
        try:
            datum = datetime.date.fromisoformat(os.path.basename(d))
        except ValueError:
            continue
        if datum < hranice:
            log(f'retence pg: mažu {d}')
            if not dry:
                shutil.rmtree(d)


def snapshot(cfg, snap, dry):
    nazev, zdroj = snap['nazev'], snap['zdroj']
    cil_dir = os.path.join(cfg['zaloha_root'], nazev)
    cil = os.path.join(cil_dir, DNES)
    minule = os.path.join(cil_dir, 'latest')
    os.makedirs(cil_dir, exist_ok=True)

    cmd = ['rsync', '-aHAX', '--numeric-ids', '--delete']
    if dry:
        cmd.append('--dry-run')
    if os.path.isdir(minule):
        cmd.append('--link-dest=' + os.path.realpath(minule))
    cmd += ['--exclude=' + e for e in snap.get('exclude', [])]
    cmd += [zdroj.rstrip('/') + '/', cil + '/']

    log(f'rsync {zdroj} -> {cil}')
    r = subprocess.run(cmd, stderr=LOG_FILE)
    # 24 = soubory zmizely během přenosu (živé systémy) — není chyba
    if r.returncode not in (0, 24):
        chyba(f'rsync {nazev} rc={r.returncode}')
    if r.returncode == 24:
        log(f'rsync {nazev}: rc=24 (vanished files) — ok')
    if not dry:
        docasny = minule + '.tmp'
        os.symlink(DNES, docasny)
        os.replace(docasny, minule)

    # retence: drží se posledních uchovat_snap adresářů dle jména
    denni = sorted(d for d in glob.glob(os.path.join(cil_dir, '20*'))
                   if os.path.isdir(d) and not os.path.islink(d))
    for d in denni[:-cfg['uchovat_snap']] if cfg['uchovat_snap'] else denni:
        log(f'retence {nazev}: mažu {d}')
        if not dry:
            shutil.rmtree(d)


def vypis_db(cfg):
    for port in cfg['clustery']:
        print(f'=== cluster :{port}')
        subprocess.run(['sudo', '-u', 'postgres', 'psql', '-p', str(port), '-c',
                        "SELECT datname AS db, pg_size_pretty(pg_database_size(datname))"
                        " AS velikost FROM pg_database WHERE NOT datistemplate"
                        " ORDER BY pg_database_size(datname) DESC"])


def main():
    global LOG_FILE
    ap = argparse.ArgumentParser(description='záloha pikomatu (PG dumpy + rsync snapshoty)')
    ap.add_argument('--config', default=CONFIG_DEFAULT, help=f'default {CONFIG_DEFAULT}')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--list', action='store_true', help='vypiš DB s velikostmi a skonči')
    args = ap.parse_args()

    cfg = nacti_config(args.config)
    os.chdir('/')   # ať sudo -u postgres nekřičí kvůli nečitelnému cwd

    if args.list:
        vypis_db(cfg)
        return

    if os.geteuid() != 0:
        chyba('spusť pod rootem')

    os.makedirs(os.path.join(cfg['zaloha_root'], 'log'), exist_ok=True)

    # jen jedna instance najednou
    zamek = open(os.path.join(cfg['zaloha_root'], '.lock'), 'w')
    try:
        fcntl.flock(zamek, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        chyba('záloha už běží, končím')

    LOG_FILE = open(os.path.join(cfg['zaloha_root'], 'log', f'zaloha-{DNES}.log'), 'a')

    log(f"=== start zálohy {DNES}{' (DRY RUN)' if args.dry_run else ''}")
    kontrola_mista(cfg)
    zalohuj_pg(cfg, args.dry_run)
    for snap in cfg['snapshoty']:
        kontrola_mista(cfg)
        snapshot(cfg, snap, args.dry_run)
    log(f"=== hotovo; volné místo: {volne_gb(cfg['zaloha_root'])} GB")


if __name__ == '__main__':
    main()
