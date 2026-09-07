#!/usr/bin/env python3
##
# pikomat-fix-perms.py — po obnově ze zálohy vrátí vlastníky a skupiny
# podle pravidel (pouštět pod rootem).
#
# Proč: záloha (pikomat-zaloha.py, volba skupina_cte_snapshoty) normalizuje
# skupinu snapshotů na "zaloha" + přidává g+r, aby šly zálohy záloh dělat
# pod ne-rootem; offsite kopie tažená pod ne-rootem navíc ztratí vlastníky
# (módy rwx rsync zachová i bez roota). Detailní vlastnictví jednotlivých
# souborů tedy v záloze není — tenhle skript ho nahradí pravidlovým vzorem
# (nejdelší prefix vyhrává) a citlivým adresářům zavře skupinu/ostatní.
#
# Použití:  pikomat-fix-perms.py <koren> [--proved]
#   <koren> = adresář obsahující www/ a pikomat/ (obnovené /home, nebo
#             přímo snapshot, třeba /home/backup/pikomat/www/latest/..
#             — pravidla se vztahují k cestám pod kořenem)
#   bez --proved jen vypíše souhrn, co by změnil
#
# POZOR: /home/www/overleaf drží data dockerových kontejnerů (mongo…) —
# uvnitř kontejnerů platí číselné uid, tady vyjdou jako náhodná jména
# (mattermost apod.). Po obnově preklepu práva doladit ručně, nebo ho
# nechat umřít (migrace na afterleaf).

import grp
import os
import pwd
import sys

# (prefix vůči kořeni, vlastník, skupina) — nejdelší shoda vyhrává.
# Vzor podle stavu serveru 2026-09-07 (find ... -printf %u:%g agregace).
PRAVIDLA = [
    ('www/sklep-data',    'www-data', 'www-data'),
    ('www/sklep-hlubina', 'www-data', 'www-data'),
    ('www/html',          'www-data', 'pikoweb'),
    ('www/git',           'root',     'pikoweb'),
    ('www/rails',         'vitas',    'pikoweb'),
    ('www/overleaf',      'root',     'pikomat'),   # docker, viz POZOR výše
    ('www',               'root',     'pikoweb'),
    ('pikomat',           'pikomat',  'pikomat'),
]

# Soukromé adresáře: zavřít skupině i ostatním (vrací g+r přidané zálohou)
SOUKROME = [
    'pikomat/mail',
    'pikomat/Mail',
    'pikomat/pomocne/secure',
]


def najdi_pravidlo(rel):
    for prefix, u, g in sorted(PRAVIDLA, key=lambda p: -len(p[0])):
        if rel == prefix or rel.startswith(prefix + '/'):
            return u, g
    return None


def main():
    args = [a for a in sys.argv[1:] if a != '--proved']
    proved = '--proved' in sys.argv
    if len(args) != 1 or not os.path.isdir(args[0]):
        sys.exit('pouziti: pikomat-fix-perms.py <koren s www/ a pikomat/> [--proved]')
    koren = os.path.abspath(args[0])

    ids = {}   # (vlastnik, skupina) -> (uid, gid)
    for _, u, g in PRAVIDLA:
        try:
            ids[(u, g)] = (pwd.getpwnam(u).pw_uid, grp.getgrnam(g).gr_gid)
        except KeyError as e:
            sys.exit(f'neznámý uživatel/skupina {e} — nejdřív založ účty, pak spusť znovu')

    chown_count = chmod_count = 0
    soukrome_abs = [os.path.join(koren, s) for s in SOUKROME]

    for adresar, podadresare, soubory in os.walk(koren):
        rel = os.path.relpath(adresar, koren)
        pravidlo = najdi_pravidlo('' if rel == '.' else rel)
        soukromy = any(adresar == s or adresar.startswith(s + '/') for s in soukrome_abs)
        for jmeno in podadresare + soubory:
            cesta = os.path.join(adresar, jmeno)
            st = os.lstat(cesta)
            if pravidlo:
                uid, gid = ids[pravidlo]
                if (st.st_uid, st.st_gid) != (uid, gid):
                    chown_count += 1
                    if proved:
                        os.lchown(cesta, uid, gid)
            if soukromy and not os.path.islink(cesta) and st.st_mode & 0o077:
                chmod_count += 1
                if proved:
                    os.chmod(cesta, st.st_mode & ~0o077)

    rezim = 'změněno' if proved else 'ke změně (pusť s --proved)'
    print(f'fix-perms {koren}: chown {rezim}: {chown_count}, '
          f'soukromí (go-rwx) {rezim}: {chmod_count}')


if __name__ == '__main__':
    main()
