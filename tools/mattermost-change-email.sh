#!/bin/bash
#
# Změna emailu (a username/aliasu) uživatele v Mattermostu (PostgreSQL).
#
# Tep umí změnit email v tepu (User + řešitelé + účastník), ale Mattermost má
# vlastní databázi. Tenhle skript přepíše email i tam – a zároveň přejmenuje
# username (to, co se v Mattermostu zobrazuje jako @alias), protože ten se
# odvozuje z emailu a sám se nezmění. Pouští se ručně na produkčním serveru
# jako root (nebo kdokoli, kdo se dostane na mattermost databázi).
#
# Použití:
#   tools/mattermost-change-email.sh STARY@EMAIL NOVY@EMAIL [NOVY_USERNAME]
#
# username se defaultně odvodí z nového emailu stejně jako to dělá Mattermost:
# malá písmena a každý znak mimo [a-z0-9._-] (typicky '@') se nahradí '-'.
# Např. vit.kadera@email.cz -> vit.kadera-email.cz. Lze přebít 3. argumentem.
#
# Idempotentní: uživatele najde podle starého i nového emailu, takže když se
# pustí podruhé (email už je změněný, ale username ne), jen dopřejmenuje. Když
# je všechno správně, neudělá nic.
#
# Flagy:
#   -y, --yes        neptat se (lze i MM_YES=1)
#   --no-username    nech username být, měň jen email
#
# Připojení k databázi se bere z proměnné PSQL (dělí se na mezerách – žádné
# uvozované argumenty). Výchozí předpoklad je, že root pustí psql pod uživatelem
# postgres do databáze "mattermost_db":
#   PSQL="sudo -u postgres psql mattermost_db"   (výchozí)
# Pro připojení přes DSN/heslo radši použij standardní PG proměnné a PSQL=psql:
#   PGHOST=localhost PGUSER=mmuser PGPASSWORD=heslo PGDATABASE=mattermost_db \
#     PSQL=psql tools/mattermost-change-email.sh a@b c@d
#
# POZOR: Mattermost si uživatele cachuje. Po změně je vhodné Mattermost
# restartovat, aby se projevila (případně použít `mmctl user edit ...`).

set -euo pipefail

PSQL="${PSQL:-sudo -u postgres psql mattermost_db}"

usage() {
  awk 'NR>=2 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
  exit 1
}

YES="${MM_YES:-0}"
DO_USERNAME=1
ARGS=()
for a in "$@"; do
  case "$a" in
    -y|--yes) YES=1 ;;
    --no-username) DO_USERNAME=0 ;;
    -h|--help) usage ;;
    *) ARGS+=("$a") ;;
  esac
done

[ "${#ARGS[@]}" -ge 2 ] && [ "${#ARGS[@]}" -le 3 ] || usage

OLD="${ARGS[0]}"
NEW="${ARGS[1]}"
USERNAME_ARG="${ARGS[2]:-}"

# Mattermost emaily ukládá malými písmeny – znormalizujeme.
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
OLD_LC="$(lc "$OLD")"
NEW_LC="$(lc "$NEW")"

# odvození username z emailu, jak to dělá Mattermost (neplatné znaky -> '-')
mm_username() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]/-/g'; }

# jednoduchá kontrola formátu nového emailu
if ! printf '%s' "$NEW_LC" | grep -Eiq '^[-_a-z0-9.+]+@[a-z0-9.-]+$'; then
  echo "Chyba: '$NEW' nevypadá jako email" >&2
  exit 2
fi

if [ "$DO_USERNAME" = "1" ]; then
  NEW_USERNAME="$(lc "${USERNAME_ARG:-$(mm_username "$NEW_LC")}")"
fi

# psql helpery – escapují jednoduché uvozovky v literálech
sql_escape() { printf "%s" "$1" | sed "s/'/''/g"; }
OLD_SQL="$(sql_escape "$OLD_LC")"
NEW_SQL="$(sql_escape "$NEW_LC")"

# $PSQL se schválně needuje (necitujeme), aby se rozdělil na slova
# (např. "sudo -u postgres psql mattermost_db").
run_psql() { $PSQL -v ON_ERROR_STOP=1 -X -q "$@"; }
# jeden řádek, pole oddělená '|'
psql_row() { run_psql -t -A -F '|' -c "$1"; }
run_sql()  { run_psql -c "$1"; }

echo "Připojení: $PSQL"
echo

# Najdeme uživatele podle starého emailu; když není, zkusíme nový (re-run).
ROW="$(psql_row "SELECT id || '|' || username || '|' || email FROM users WHERE lower(email) = lower('$OLD_SQL')")"
if [ -z "$ROW" ]; then
  ROW="$(psql_row "SELECT id || '|' || username || '|' || email FROM users WHERE lower(email) = lower('$NEW_SQL')")"
  if [ -z "$ROW" ]; then
    echo "V Mattermostu není uživatel s emailem '$OLD' ani '$NEW'. Nic neměním." >&2
    exit 3
  fi
  echo "Uživatel se starým emailem nenalezen, ale existuje s novým emailem – režim opravy username."
fi

IFS='|' read -r U_ID U_NAME U_EMAIL <<<"$ROW"
echo "Nalezený uživatel:"
echo "  id:       $U_ID"
echo "  username: $U_NAME"
echo "  email:    $U_EMAIL"
echo

# Co je potřeba změnit
CHANGE_EMAIL=0
[ "$(lc "$U_EMAIL")" != "$NEW_LC" ] && CHANGE_EMAIL=1

CHANGE_USERNAME=0
if [ "$DO_USERNAME" = "1" ] && [ "$(lc "$U_NAME")" != "$NEW_USERNAME" ]; then
  CHANGE_USERNAME=1
fi

if [ "$CHANGE_EMAIL" = "0" ] && [ "$CHANGE_USERNAME" = "0" ]; then
  echo "Email i username jsou už správně. Není co měnit."
  exit 0
fi

# Kolize: cílový email / username nesmí mít nikdo jiný
if [ "$CHANGE_EMAIL" = "1" ]; then
  TAKEN="$(psql_row "SELECT id || '|' || username || '|' || email FROM users WHERE lower(email) = lower('$NEW_SQL') AND id <> '$(sql_escape "$U_ID")'")"
  if [ -n "$TAKEN" ]; then
    echo "Email '$NEW' už v Mattermostu někdo používá – NEPROVÁDÍM nic:" >&2
    echo "  $TAKEN" >&2
    exit 4
  fi
fi
if [ "$CHANGE_USERNAME" = "1" ]; then
  NU_SQL="$(sql_escape "$NEW_USERNAME")"
  TAKEN="$(psql_row "SELECT id || '|' || username || '|' || email FROM users WHERE lower(username) = lower('$NU_SQL') AND id <> '$(sql_escape "$U_ID")'")"
  if [ -n "$TAKEN" ]; then
    echo "Username '$NEW_USERNAME' už v Mattermostu někdo používá – NEPROVÁDÍM nic:" >&2
    echo "  $TAKEN" >&2
    exit 5
  fi
fi

echo "Provedu:"
[ "$CHANGE_EMAIL" = "1" ]    && echo "  email:    '$U_EMAIL' -> '$NEW_LC'"
[ "$CHANGE_USERNAME" = "1" ] && echo "  username: '$U_NAME' -> '$NEW_USERNAME'"

if [ "$YES" != "1" ]; then
  read -r -p "Pokračovat? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) echo "Zrušeno."; exit 0 ;;
  esac
fi

# Sestavíme jeden UPDATE
SET=""
[ "$CHANGE_EMAIL" = "1" ]    && SET="email = '$NEW_SQL'"
if [ "$CHANGE_USERNAME" = "1" ]; then
  [ -n "$SET" ] && SET="$SET, "
  SET="${SET}username = '$(sql_escape "$NEW_USERNAME")'"
fi
run_sql "UPDATE users SET $SET WHERE id = '$(sql_escape "$U_ID")'"

echo "Hotovo. Kvůli cache je potřeba restartovat Mattermost – spusť:"
echo "    systemctl restart mattermost"
