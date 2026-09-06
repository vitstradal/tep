#!/usr/bin/env python3
"""sklep-dedup.py — mazání duplikátů ve sklep datech podle md5 seznamu.

Vstup: soubor ve formátu `md5sum` (hash, dvě mezery, cesta), SETŘÍDĚNÝ
podle hashe (skupiny stejného obsahu jsou pod sebou).

Pravidla (v tomto pořadí):
  1. soubor z data-10.0.10/ se smaže, když stejný obsah (md5) existuje
     kdekoli v data-18.0.3/
  2. soubor z data-18.0.3/ se smaže, když stejný obsah existuje
     v kanonickém stromu data-18.0.3/tep-vitas@matfyz.cz/files/pikomat/
     (kanonické soubory samotné se nikdy nemažou)

Použití:
  ./sklep-dedup.py seznam.md5 --dry        # vypíše „cesta  (drží: záloha)"
  ./sklep-dedup.py seznam.md5              # totéž co --dry
  ./sklep-dedup.py seznam.md5 --delete     # opravdu maže
  ./sklep-dedup.py seznam.md5 --base /home/www/sklep-data
                                           # kořen pro relativní cesty

POZOR:
  - data-18.0.3 jsou ŽIVÁ data Nextcloudu (sklepu)! Po mazání pravidlem 2
    je NUTNÉ přepočítat filecache:  sudo -u www-data php occ files:scan --all
    jinak Nextcloud dál ukazuje smazané soubory (duchové).
  - prázdné soubory mají všechny stejný hash — jsou si navzájem
    „duplikátem"; skript je proto přeskakuje (--i-prazdne to vypne).
  - md5sum escapuje cesty s \\n a \\ (řádek začíná '\\') — takové řádky
    skript přeskočí a ohlásí (ručně).
"""

import argparse
import os
import sys

MD5_PRAZDNY = "d41d8cd98f00b204e9800998ecf8427e"
STARA = "data-10.0.10/"
NOVA = "data-18.0.3/"
KANON = "data-18.0.3/tep-vitas@matfyz.cz/files/pikomat/"


def zpracuj_skupinu(cesty, ke_smazani, preskoc_prazdne, md5):
    """Do ke_smazani přidá dvojice (cesta, kdo_obsah_drzi_dal)."""
    if preskoc_prazdne and md5 == MD5_PRAZDNY:
        return
    kanonicke = [c for c in cesty if c.startswith(KANON)]
    nove = [c for c in cesty if c.startswith(NOVA)]
    for c in cesty:
        if c.startswith(STARA):
            if nove:
                # zálohu hlas přednostně kanonickou (ta přežije i pravidlo 2)
                ke_smazani.append((c, kanonicke[0] if kanonicke else nove[0]))
        elif c.startswith(NOVA) and not c.startswith(KANON):
            if kanonicke:
                ke_smazani.append((c, kanonicke[0]))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("seznam", help="md5sum výstup setříděný podle hashe")
    ap.add_argument("--dry", action="store_true",
                    help="jen vypiš, co by se mazalo, se zálohou v závorce "
                         "(default, když není --delete)")
    ap.add_argument("--delete", action="store_true",
                    help="opravdu mazat")
    ap.add_argument("--base", default=".",
                    help="kořen, vůči kterému jsou cesty (default: .)")
    ap.add_argument("--i-prazdne", action="store_true",
                    help="nepřeskakovat prázdné soubory (md5 d41d8...)")
    args = ap.parse_args()
    if args.dry and args.delete:
        ap.error("--dry a --delete se vylučují")

    ke_smazani = []
    preskoceno_escape = 0
    minule_md5 = None
    skupina = []

    with open(args.seznam, encoding="utf-8", errors="surrogateescape") as f:
        for radek in f:
            radek = radek.rstrip("\n")
            if not radek:
                continue
            if radek.startswith("\\"):     # md5sum escape (cesta s \n / \)
                preskoceno_escape += 1
                continue
            md5, oddelovac, cesta = radek[:32], radek[32:34], radek[34:]
            if len(md5) != 32 or oddelovac not in ("  ", " *"):
                print(f"VAROVANI: divny radek, preskakuji: {radek!r}",
                      file=sys.stderr)
                continue
            if md5 != minule_md5 and skupina:
                zpracuj_skupinu(skupina, ke_smazani, not args.i_prazdne,
                                minule_md5)
                skupina = []
            minule_md5 = md5
            skupina.append(cesta)
        if skupina:
            zpracuj_skupinu(skupina, ke_smazani, not args.i_prazdne,
                            minule_md5)

    smazano = chybi = 0
    for cesta, zaloha in ke_smazani:
        if args.delete:
            try:
                os.remove(os.path.join(args.base, cesta))
                smazano += 1
            except FileNotFoundError:
                chybi += 1
                print(f"VAROVANI: neexistuje: {cesta}", file=sys.stderr)
        else:
            print(f"{cesta}  (drží: {zaloha})")

    stara = sum(1 for c, _ in ke_smazani if c.startswith(STARA))
    nova = len(ke_smazani) - stara
    print(f"# celkem k smazani: {len(ke_smazani)} "
          f"(z {STARA}: {stara}, z {NOVA}: {nova})", file=sys.stderr)
    if preskoceno_escape:
        print(f"# preskoceno {preskoceno_escape} radku s md5sum escapem "
              f"(cesty s \\n apod.) — vyres rucne", file=sys.stderr)
    if args.delete:
        print(f"# smazano: {smazano}, nenalezeno: {chybi}", file=sys.stderr)
        if nova:
            print("# NEZAPOMEN: sudo -u www-data php occ files:scan --all "
                  "(mazalo se v zivych datech Nextcloudu!)", file=sys.stderr)
    else:
        print("# dry-run — nic nesmazano; maz s --delete", file=sys.stderr)


if __name__ == "__main__":
    main()
