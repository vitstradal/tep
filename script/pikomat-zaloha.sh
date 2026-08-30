#!/bin/bash
##
# pikomat-zaloha.sh — záloha pikomatu (pouštět pod rootem na pikomatu)
#
# Zálohuje:
#   1. PostgreSQL: VŠECHNY databáze z clusterů :5432 (PG15: tep_db,
#      mattermost_db/klep, nextcloud/sklep, ...) a :5435 (PG17)
#      — per-DB pg_dump -Fc (komprimovaný, granulární restore)
#      + globals (role/tablespaces) per cluster.
#   2. /home/www     (369 GB: sklep data, rails, overleaf, html)
#   3. /home/pikomat (5 GB)
#      — rsync snapshoty s --link-dest: každý den vlastní adresář,
#        nezměněné soubory jsou hardlinky (platí se jen za rozdíly).
#
# Cíl: /backup/pikomat na kořenovém disku (sdb1) — jiný fyzický disk
# než /home (md0). NENÍ to offsite záloha — proti požáru/krádeži
# nechrání; offsite řešit zvlášť (restic/rclone jinam).
#
# POZOR: overleaf (preklep) drží projekty v MongoDB (docker) — file-level
# kopie běžícího monga v /home/www/overleaf/data nemusí být konzistentní.
# Konzistentní dump: docker exec <mongo-kontejner> mongodump --archive
# (doplnit, pokud na preklepu záleží; po migraci na afterleaf odpadá).
#
# Použití:  pikomat-zaloha.sh [--dry-run]
# Cron (doporučeno, /etc/cron.d/pikomat-zaloha):
#   30 3 * * * root /usr/local/sbin/pikomat-zaloha.sh >/dev/null 2>&1
#
# Obnova:
#   pg_restore -p 5432 -U postgres -d <db> --clean pg/<datum>/<db>-5432.dump
#   globals: zstdcat globals-5432.sql.zst | sudo -u postgres psql -p 5432
#   soubory: prostě rsync/cp z www/<datum>/ zpět.

set -euo pipefail

ZALOHA_ROOT="/backup/pikomat"
DNES=$(date +%F)
UCHOVAT_PG_DNU=14        # kolik dní držet PG dumpy
UCHOVAT_SNAP=5           # kolik denních rsync snapshotů držet
CLUSTERY="5432 5435"     # PG porty
MIN_VOLNE_GB=50          # tvrdá stopka, ať záloha nezaplní disk

# Výběr databází:
#  ZALOHUJ_DB   — whitelist (oddělený mezerami); neprázdný = dumpuj JEN tyto
#  NEZALOHUJ_DB — blacklist; použije se, když je whitelist prázdný
# Seznam DB s velikostmi vypíše: pikomat-zaloha.sh --list
ZALOHUJ_DB=""
NEZALOHUJ_DB="mailman3web"

cd /   # ať sudo -u postgres nekřičí kvůli nečitelnému cwd

DRY=""
case "${1:-}" in
  --dry-run) DRY="--dry-run" ;;
  --list)
    for port in $CLUSTERY; do
      echo "=== cluster :$port"
      sudo -u postgres psql -p "$port" -c \
        "SELECT datname AS db, pg_size_pretty(pg_database_size(datname)) AS velikost
         FROM pg_database WHERE NOT datistemplate ORDER BY pg_database_size(datname) DESC"
    done
    exit 0 ;;
esac

LOG_DIR="$ZALOHA_ROOT/log"
LOG="$LOG_DIR/zaloha-$DNES.log"
mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

# jen jedna instance najednou
exec 9>"$ZALOHA_ROOT/.lock"
flock -n 9 || { echo "zaloha uz bezi, koncim"; exit 1; }

[ "$(id -u)" = "0" ] || { echo "spust pod rootem"; exit 1; }

volne_gb() { df --output=avail -BG "$ZALOHA_ROOT" | tail -1 | tr -dc 0-9; }

kontrola_mista() {
  local v; v=$(volne_gb)
  if [ "$v" -lt "$MIN_VOLNE_GB" ]; then
    log "CHYBA: malo mista ($v GB < $MIN_VOLNE_GB GB) — koncim"
    exit 1
  fi
}

log "=== start zalohy $DNES ${DRY:+(DRY RUN)}"
kontrola_mista

############################################################
# 1. PostgreSQL
############################################################
PG_DIR="$ZALOHA_ROOT/pg/$DNES"
mkdir -p "$PG_DIR"

for port in $CLUSTERY; do
  if ! sudo -u postgres pg_isready -q -p "$port"; then
    log "pg :$port nebezi — preskakuji"
    continue
  fi
  log "pg :$port — globals"
  if [ -z "$DRY" ]; then
    sudo -u postgres pg_dumpall -p "$port" --globals-only \
      | zstd -q -o "$PG_DIR/globals-$port.sql.zst" -f
  fi
  # ne-template databaze, filtrovane pres ZALOHUJ_DB / NEZALOHUJ_DB
  for db in $(sudo -u postgres psql -p "$port" -At \
              -c "SELECT datname FROM pg_database WHERE NOT datistemplate"); do
    if [ -n "$ZALOHUJ_DB" ]; then
      case " $ZALOHUJ_DB " in *" $db "*) ;; *) log "pg :$port — $db preskocena (neni v ZALOHUJ_DB)"; continue ;; esac
    else
      case " $NEZALOHUJ_DB " in *" $db "*) log "pg :$port — $db preskocena (NEZALOHUJ_DB)"; continue ;; esac
    fi
    log "pg :$port — dump $db"
    if [ -z "$DRY" ]; then
      # pg_dump bezi jako postgres, do souboru zapisuje root (redirect) —
      # postgres do /backup psat nesmi
      sudo -u postgres pg_dump -p "$port" -Fc "$db" > "$PG_DIR/$db-$port.dump"
    fi
  done
done

# retence dumpu
find "$ZALOHA_ROOT/pg" -mindepth 1 -maxdepth 1 -type d \
     -mtime +"$UCHOVAT_PG_DNU" -print | while read -r d; do
  log "retence pg: mazu $d"
  [ -z "$DRY" ] && rm -rf "$d"
done

############################################################
# 2. + 3. rsync snapshoty souboru
############################################################
snapshot() {
  local nazev=$1 zdroj=$2; shift 2
  local cil_dir="$ZALOHA_ROOT/$nazev"
  local cil="$cil_dir/$DNES"
  local minule="$cil_dir/latest"
  mkdir -p "$cil_dir"

  local linkdest=()
  [ -d "$minule" ] && linkdest=(--link-dest="$(readlink -f "$minule")")

  log "rsync $zdroj -> $cil"
  # 24 = soubory zmizely behem prenosu (zive systemy) — neni chyba
  rsync -aHAX --numeric-ids --delete $DRY \
        "${linkdest[@]}" "$@" \
        "$zdroj/" "$cil/" 2>>"$LOG" || {
    rc=$?
    if [ "$rc" -ne 24 ]; then log "CHYBA: rsync $nazev rc=$rc"; exit "$rc"; fi
    log "rsync $nazev: rc=24 (vanished files) — ok"
  }
  if [ -z "$DRY" ]; then
    ln -sfn "$DNES" "$minule"
  fi

  # retence snapshotu (drzi se poslednich UCHOVAT_SNAP adresaru dle jmena)
  find "$cil_dir" -mindepth 1 -maxdepth 1 -type d -name "20*" \
  | sort | head -n -"$UCHOVAT_SNAP" | while read -r d; do
    log "retence $nazev: mazu $d"
    [ -z "$DRY" ] && rm -rf "$d"
  done
}

kontrola_mista
snapshot www /home/www \
  --exclude=/rails/passenger-tmp \
  --exclude=/overleaf/data/mongo/journal
kontrola_mista
snapshot pikomat /home/pikomat

log "=== hotovo; volne misto: $(volne_gb) GB"
df -h "$ZALOHA_ROOT" | tail -1 | tee -a "$LOG"
