#!/bin/bash
##
# luks-zkus-hesla.sh — vyzkouší kandidátní hesla proti LUKS oddílu.
#
# Pro případ "vím, že je to jedno z mých pár hesel, ale nevím které".
# NENÍ to prolamovač: jen po řadě zkouší hesla ze souboru přes
# `cryptsetup open --test-passphrase`, což je totéž, co dělá odemykání,
# jen bez namapování zařízení. Nic na disku nemění (jen čte hlavičku).
#
# Použití:
#   luks-zkus-hesla.sh /dev/sdb1 hesla.txt
#     hesla.txt = kandidáti, JEDNO heslo na řádek (i s mezerami; bez
#     trailing newline manipulace). Prázdné řádky a řádky začínající #
#     se přeskočí.
#
# Tipy když si nejsi jistý přesným tvarem:
#   - varianty (velké písmeno, číslice na konci, s/bez diakritiky) dej
#     do souboru jako samostatné řádky — pár desítek/stovek je otázka
#     vteřin, LUKS2 je ale záměrně pomalý (Argon2), počítej ~0,5–2 s/heslo
#   - když nevíš kódování diakritiky, přidej UTF-8 i variantu bez háčků

set -u

DEV=${1:-}
SOUBOR=${2:-}
if [ -z "$DEV" ] || [ -z "$SOUBOR" ]; then
  echo "pouziti: $0 <luks-oddil> <soubor-s-hesly>" >&2
  echo "  napr.: $0 /dev/sdb1 hesla.txt" >&2
  exit 2
fi
[ -r "$SOUBOR" ] || { echo "nelze cist $SOUBOR" >&2; exit 2; }

# --test-passphrase potrebuje pristup k zarizeni → nejspis root
if [ "$(id -u)" != 0 ]; then
  echo "pozn.: bezis bez roota; pokud selze cteni $DEV, spust pres sudo" >&2
fi

if ! cryptsetup isLuks "$DEV" 2>/dev/null; then
  echo "CHYBA: $DEV nevypada jako LUKS oddil" >&2
  exit 2
fi

pocet=$(grep -cvE '^\s*(#|$)' "$SOUBOR")
echo "zkousim $pocet kandidatu proti $DEV ..."
i=0
# IFS= a -r: zachovej mezery i zpetna lomitka v hesle
while IFS= read -r heslo || [ -n "$heslo" ]; do
  case "$heslo" in ''|\#*) continue ;; esac
  i=$((i+1))
  # heslo posilame na stdin BEZ pridaneho newline (printf %s), aby sedelo
  # presne to, co jsi napsal do souboru
  if printf %s "$heslo" | cryptsetup open --test-passphrase "$DEV" 2>/dev/null; then
    echo
    echo "=========================================="
    echo "NALEZENO (radek $i): $heslo"
    echo "=========================================="
    echo "odemcit:  printf %s '$heslo' | sudo cryptsetup open $DEV kingston"
    exit 0
  fi
  printf '\r  %d/%d' "$i" "$pocet" >&2
done < "$SOUBOR"

echo >&2
echo "zadne z $i hesel nesedelo." >&2
echo "pozn.: cryptsetup pridava newline jen kdyz heslo zadavas interaktivne;" >&2
echo "       kdyz jsi ho zadaval pres GUI/jinak, muze byt tvar jiny — zkus" >&2
echo "       varianty s koncovym newline: sed 's/\$/\\n/' apod." >&2
exit 1
