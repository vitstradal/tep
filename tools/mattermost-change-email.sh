#!/bin/bash
#
# Změna emailu uživatele v Mattermostu (PostgreSQL).
#
# Tep umí změnit email v tepu (User + řešitelé + účastník), ale Mattermost má
# vlastní databázi. Tenhle skript přepíše email i tam. Pouští se ručně na
# produkčním serveru jako root (nebo kdokoli, kdo se dostane na mattermost DB).
#
# Použití:
#   tools/mattermost-change-email.sh STARY@EMAIL NOVY@EMAIL
#
# Připojení k databázi se bere ze standardních PG proměnných, případně z
# proměnné PSQL, kterou lze celou přebít. Výchozí předpoklad je, že root pustí
# psql pod uživatelem postgres do databáze "mattermost":
#
#   PSQL="sudo -u postgres psql mattermost"   (výchozí)
#
# Dá se přebít, např.:
#   PSQL="psql 'postgres://mmuser:heslo@localhost/mattermost'" tools/mattermost-change-email.sh a@b c@d
#
# Bez ptaní (neinteraktivně) přidej -y nebo nastav MM_YES=1.
#
# POZOR: Mattermost si uživatele cachuje. Po změně je vhodné Mattermost
# restartovat, aby se nový email projevil (případně použít `mmctl user edit ...`,
# které cache řeší samo).

set -euo pipefail

PSQL="${PSQL:-sudo -u postgres psql mattermost}"

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

YES="${MM_YES:-0}"
ARGS=()
for a in "$@"; do
  case "$a" in
    -y|--yes) YES=1 ;;
    -h|--help) usage ;;
    *) ARGS+=("$a") ;;
  esac
done

[ "${#ARGS[@]}" -eq 2 ] || usage

OLD="${ARGS[0]}"
NEW="${ARGS[1]}"

# Mattermost emaily ukládá malými písmeny – znormalizujeme.
OLD_LC="$(printf '%s' "$OLD" | tr '[:upper:]' '[:lower:]')"
NEW_LC="$(printf '%s' "$NEW" | tr '[:upper:]' '[:lower:]')"

# jednoduchá kontrola formátu nového emailu
if ! printf '%s' "$NEW_LC" | grep -Eiq '^[-_a-z0-9.+]+@[a-z0-9.-]+$'; then
  echo "Chyba: '$NEW' nevypadá jako email" >&2
  exit 2
fi

# psql helper – escapuje jednoduché uvozovky pro literály
sql_escape() { printf "%s" "$1" | sed "s/'/''/g"; }
OLD_SQL="$(sql_escape "$OLD_LC")"
NEW_SQL="$(sql_escape "$NEW_LC")"

run_sql() { eval "$PSQL" -v ON_ERROR_STOP=1 -X -q -c "\"$1\""; }
run_sql_t() { eval "$PSQL" -v ON_ERROR_STOP=1 -X -q -t -A -c "\"$1\""; }

echo "Připojení: $PSQL"
echo

# Najdeme uživatele se starým emailem
FOUND="$(run_sql_t "SELECT id || '  ' || username || '  ' || email FROM users WHERE lower(email) = lower('$OLD_SQL')")"
if [ -z "$FOUND" ]; then
  echo "V Mattermostu není žádný uživatel s emailem '$OLD'. Nic neměním." >&2
  exit 3
fi
echo "Najdený uživatel (id  username  email):"
echo "  $FOUND"

# Cílový email už nesmí mít nikdo jiný
TAKEN="$(run_sql_t "SELECT id || '  ' || username || '  ' || email FROM users WHERE lower(email) = lower('$NEW_SQL') AND lower(email) <> lower('$OLD_SQL')")"
if [ -n "$TAKEN" ]; then
  echo >&2
  echo "Email '$NEW' už v Mattermostu někdo používá – změnu NEPROVÁDÍM:" >&2
  echo "  $TAKEN" >&2
  exit 4
fi

echo
echo "Změním email '$OLD_LC' -> '$NEW_LC'."
if [ "$YES" != "1" ]; then
  read -r -p "Pokračovat? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) echo "Zrušeno."; exit 0 ;;
  esac
fi

run_sql "UPDATE users SET email = '$NEW_SQL' WHERE lower(email) = lower('$OLD_SQL')"

echo "Hotovo. Doporučuju restartovat Mattermost (kvůli cache)."
