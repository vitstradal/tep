#!/bin/bash
# Upgrade Mattermostu z tarballu se zálohou a rollbackem; použití: mattermost-upgrade.sh --help
set -Eeuo pipefail
shopt -s inherit_errexit

MM_DIR=${MM_DIR:-/opt/mattermost}
UNIT=${MM_UNIT:-mattermost.service}
BACKUP_ROOT=${MM_BACKUP_ROOT:-/opt/mattermost-backups}
RELEASES=https://releases.mattermost.com
GH_API=https://api.github.com/repos/mattermost/mattermost/releases
NOTES_URL=https://docs.mattermost.com/administration-guide/upgrade/important-upgrade-notes.html
MARGIN_KB=$((5 * 1024 * 1024))
KEEP_TOP=(config data logs plugins)

ASSUME_YES=0
FORCE_JUMP=0
PHASE=pre
STAGE=""
BK=""

usage() {
	cat <<EOF
Použití (pod rootem):
  $0 check [VERZE|latest]     jen kontroly, nic nemění
  $0 upgrade VERZE|latest     stáhne, ověří, zastaví, zazálohuje, vymění, pustí, ověří
  $0 rollback [ADRESAR]       vrátí aplikaci i DB ze zálohy (výchozí: nejnovější)
  $0 list                     vypíše zálohy

Přepínače: --yes (neptá se před zastavením), --force-jump (povolí skok o víc než 1 major)
Prostředí: MM_DIR=$MM_DIR MM_UNIT=$UNIT MM_BACKUP_ROOT=$BACKUP_ROOT
EOF
}

log()  { printf '%s  %s\n' "$(date +%T)" "$*"; }
ok()   { printf '%s  [ OK ] %s\n' "$(date +%T)" "$*"; }
warn() { printf '%s  [WARN] %s\n' "$(date +%T)" "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
die()  { printf '%s  [FAIL] %s\n' "$(date +%T)" "$*" >&2; exit 1; }
WARNINGS=0

confirm() {
	local word=$1; shift
	[[ $ASSUME_YES == 1 && $word == ano ]] && return 0
	[[ -r /dev/tty ]] || die "není terminál pro potvrzení (zkus --yes)"
	printf '\n%s\nNapiš "%s" pro pokračování: ' "$*" "$word" >/dev/tty
	local answer
	read -r answer </dev/tty
	[[ $answer == "$word" ]] || die "zrušeno uživatelem"
}

on_exit() {
	local rc=$?
	trap - EXIT
	if [[ -n $STAGE && -d $STAGE && $STAGE == "$(dirname "$MM_DIR")"/.mattermost-stage.* ]]; then
		rm -rf -- "$STAGE"
	fi
	[[ $rc == 0 ]] && exit 0
	case $PHASE in
	pre)
		log "Skončilo chybou PŘED zastavením služby: na serveru se nic nezměnilo." ;;
	stopped)
		log "Skončilo chybou po zastavení služby, původní instalace je netknutá: pouštím ji zpět."
		if systemctl start "$UNIT"; then log "Služba $UNIT zase běží (stará verze)."
		else log "!!! Službu $UNIT se nepodařilo pustit: journalctl -u $UNIT -e"; fi ;;
	swapped)
		log "!!! Skončilo chybou PO výměně verze. Stav nech být a rozhodni se:"
		log "!!!   log:      journalctl -u $UNIT -e"
		log "!!!   rollback: $0 rollback $BK" ;;
	rollback)
		log "!!! Rollback skončil chybou uprostřed: zkontroluj ručně $MM_DIR, DB a $BK." ;;
	esac
	exit "$rc"
}

need_cmds() {
	local c missing=()
	for c in "$@"; do command -v "$c" >/dev/null || missing+=("$c"); done
	[[ ${#missing[@]} == 0 ]] || die "chybí příkazy: ${missing[*]}"
}

tree_sig() { find "$1" -type f -printf '%s\n' | awk '{n++; s+=$1} END {print n+0, s+0}'; }

ver_gt() { [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1) == "$1" ]]; }

pg() { runuser -u postgres -- psql -X -At -v ON_ERROR_STOP=1 -p "$DB_PORT" "$@"; }

mm_version_of() {
	runuser -u "$RUN_USER" -- bash -c 'cd "$1" && timeout 120 bin/mattermost version 2>&1' _ "$1" |
		awk '$1 == "Version:" {print $2; exit}' || true
}

ping_version() {
	local out
	out=$(curl -sS -k -i -m 10 "$PING_URL" 2>/dev/null) || return 1
	grep -q '"status":"OK"' <<<"$out" || return 1
	awk 'tolower($1) == "x-version-id:" {split($2, a, "."); print a[1] "." a[2] "." a[3]; exit}' <<<"$out" | tr -d '\r'
}

wait_stopped() {
	local i
	for i in $(seq 1 45); do
		if ! systemctl is-active --quiet "$UNIT" && ! pgrep -u "$RUN_USER" >/dev/null; then return 0; fi
		sleep 2
	done
	pgrep -u "$RUN_USER" -a >&2 || true
	die "po 90 s stále běží procesy uživatele $RUN_USER"
}

check_cfg_path() {
	local name=$1 value=$2 abs p
	[[ -n $value && $value != null ]] || return 0
	if [[ $value == /* ]]; then abs=$(realpath -m "$value"); else abs=$(realpath -m "$MM_DIR/$value"); fi
	if [[ $abs != "$MM_DIR" && $abs != "$MM_DIR"/* ]]; then
		ok "$name = $value leží mimo $MM_DIR, upgrade se ho nedotkne"
		return 0
	fi
	for p in "${KEEP_TOP[@]}" client/plugins; do
		[[ $abs == "$MM_DIR/$p" || $abs == "$MM_DIR/$p"/* ]] && return 0
	done
	EXTRA_CFG+=("${abs#"$MM_DIR"/}")
	warn "$name = $value není standardní zachovávaný adresář; přenesu ho také"
}

load_install() {
	[[ $EUID == 0 ]] || die "pusť pod rootem (sudo)"
	need_cmds curl jq tar sha256sum systemctl runuser pg_dump pg_restore psql ss flock df du stat find sort awk realpath pgrep timeout cmp
	cd /
	[[ $MM_DIR == /* && ! -L $MM_DIR && -d $MM_DIR ]] || die "$MM_DIR není skutečný adresář"
	MM_DIR=$(realpath "$MM_DIR")
	[[ -x $MM_DIR/bin/mattermost ]] || die "chybí $MM_DIR/bin/mattermost"
	CFG=$MM_DIR/config/config.json
	[[ -s $CFG ]] || die "chybí $CFG"
	jq empty "$CFG" || die "$CFG není platný JSON"

	systemctl cat "$UNIT" >/dev/null 2>&1 || die "systemd unit $UNIT neexistuje"
	[[ $(systemctl show "$UNIT" -p ExecStart --value) == *"$MM_DIR/bin/mattermost"* ]] ||
		die "$UNIT nespouští $MM_DIR/bin/mattermost"
	RUN_USER=$(systemctl show "$UNIT" -p User --value)
	RUN_GROUP=$(systemctl show "$UNIT" -p Group --value)
	[[ -n $RUN_USER && $RUN_USER != root ]] || die "$UNIT nemá vyhrazeného uživatele (User=)"
	id "$RUN_USER" >/dev/null || die "uživatel $RUN_USER neexistuje"
	[[ -n $RUN_GROUP ]] || RUN_GROUP=$(id -gn "$RUN_USER")
	[[ $(stat -c %U "$MM_DIR") == "$RUN_USER" ]] || die "$MM_DIR nepatří uživateli $RUN_USER"
	if systemctl show "$UNIT" -p Environment -p EnvironmentFiles --value | grep -q 'MM_'; then
		die "$UNIT nastavuje proměnné MM_*: konfigurace není jen v config.json, tohle skript neumí"
	fi

	[[ $(jq -r '.SqlSettings.DriverName' "$CFG") == postgres ]] || die "DB není postgres"
	local dsn hostport host
	dsn=$(jq -r '.SqlSettings.DataSource' "$CFG")
	[[ $dsn =~ ^postgres(ql)?://([^@]*@)?([^/?]*)/([^?]+)(\?.*)?$ ]] || die "nerozumím SqlSettings.DataSource"
	hostport=${BASH_REMATCH[3]}
	DB_NAME=${BASH_REMATCH[4]}
	[[ $DB_NAME =~ ^[A-Za-z0-9_]+$ ]] || die "podezřelé jméno DB: $DB_NAME"
	DB_PORT=5432
	host=$hostport
	if [[ $hostport =~ ^(.*):([0-9]+)$ ]]; then host=${BASH_REMATCH[1]}; DB_PORT=${BASH_REMATCH[2]}; fi
	case $host in "" | localhost | 127.0.0.1 | "[::1]") ;; *) die "DB běží na $host, skript umí jen lokální PostgreSQL" ;; esac

	[[ $(jq -r '.FileSettings.DriverName' "$CFG") == local ]] || die "FileSettings.DriverName není local"
	EXTRA_CFG=()
	check_cfg_path FileSettings.Directory "$(jq -r '.FileSettings.Directory' "$CFG")"
	check_cfg_path PluginSettings.Directory "$(jq -r '.PluginSettings.Directory' "$CFG")"
	check_cfg_path PluginSettings.ClientDirectory "$(jq -r '.PluginSettings.ClientDirectory' "$CFG")"
	check_cfg_path LogSettings.FileLocation "$(jq -r '.LogSettings.FileLocation // ""' "$CFG")"
	if [[ $(jq -r '.BleveSettings.EnableIndexing // false' "$CFG") == true ]]; then
		check_cfg_path BleveSettings.IndexDir "$(jq -r '.BleveSettings.IndexDir' "$CFG")"
		warn "Bleve je zapnuté; od v11 neexistuje, před upgradem nastav DisableDatabaseSearch=false"
	fi

	local listen subpath scheme=http
	listen=$(jq -r '.ServiceSettings.ListenAddress' "$CFG")
	MM_PORT=${listen##*:}
	[[ $MM_PORT =~ ^[0-9]+$ ]] || die "nerozumím ListenAddress: $listen"
	[[ $(jq -r '.ServiceSettings.ConnectionSecurity // ""' "$CFG") == TLS ]] && scheme=https
	subpath=$(jq -r '.ServiceSettings.SiteURL' "$CFG" | sed -E 's,^[a-z]+://[^/]*,,; s,/+$,,')
	PING_URL="$scheme://127.0.0.1:$MM_PORT$subpath/api/v4/system/ping"
}

preflight() {
	local want=$1
	load_install
	ok "instalace $MM_DIR, unit $UNIT, běží jako $RUN_USER:$RUN_GROUP"

	systemctl is-active --quiet "$UNIT" || die "$UNIT teď neběží; nejdřív zjisti proč, upgrade na rozbitý stav nepouštím"
	CUR_VER=$(mm_version_of "$MM_DIR")
	[[ $CUR_VER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "nezjistil jsem běžící verzi (bin/mattermost version)"
	EDITION=$(awk -F= '$1 == "EDITION" {print $2}' "$MM_DIR/manifest.txt" 2>/dev/null || true)
	[[ $EDITION == enterprise || $EDITION == team ]] || die "nezjistil jsem edici z $MM_DIR/manifest.txt"
	ok "nainstalováno $CUR_VER ($EDITION)"

	local live
	live=$(ping_version) || die "health check $PING_URL neodpovídá status OK"
	[[ $live == "$CUR_VER" ]] || die "běžící server hlásí $live, binárka na disku $CUR_VER: někdo sahal do instalace?"
	ok "health check $PING_URL: OK, verze $live"

	[[ $(pg -d postgres -c "SELECT count(*) FROM pg_database WHERE datname = '$DB_NAME'") == 1 ]] ||
		die "DB $DB_NAME na portu $DB_PORT neexistuje"
	PG_NUM=$(pg -d postgres -c 'SHOW server_version_num')
	DB_BYTES=$(pg -d postgres -c "SELECT pg_database_size('$DB_NAME')")
	(( PG_NUM >= 140000 )) || die "PostgreSQL $PG_NUM je pro Mattermost 11+ moc starý"
	ok "DB $DB_NAME na :$DB_PORT, PostgreSQL $PG_NUM, $((DB_BYTES / 1024 / 1024)) MB"

	[[ $(uname -m) == x86_64 ]] || die "skript umí jen linux-amd64"
	if [[ $want == latest ]]; then
		want=$(curl -fsS -m 20 "$GH_API/latest" | jq -r '.tag_name' | sed 's/^v//') || die "nezjistil jsem nejnovější verzi z GitHubu"
		log "nejnovější stabilní verze podle GitHubu: $want"
	fi
	TARGET=$want
	[[ $TARGET =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "verze musí být X.Y.Z (žádné rc), dostal jsem: $TARGET"
	ver_gt "$TARGET" "$CUR_VER" || die "$TARGET není novější než $CUR_VER; downgrade ani reinstalaci nedělám"

	local cmaj=${CUR_VER%%.*} tmaj=${TARGET%%.*}
	if (( tmaj - cmaj > 1 )) && [[ $FORCE_JUMP != 1 ]]; then
		log "dostupné verze řady $((cmaj + 1)).x:"
		curl -fsS -m 20 "$GH_API?per_page=100" | jq -r '.[] | select(.prerelease | not) | .tag_name' |
			grep -E "^v$((cmaj + 1))\." | sort -V | sed 's/^/    /' || true
		die "skok $CUR_VER -> $TARGET přeskakuje major verzi; jdi nejdřív na poslední ESR řady $((cmaj + 1)).x (nebo --force-jump)"
	fi
	if (( tmaj == 11 )) && ! ver_gt "$TARGET" 11.7.2; then
		die "dokumentace zakazuje upgrade z 10.11.17+ na 11.x starší než 11.7.3 ($NOTES_URL)"
	fi
	(( tmaj < 12 || PG_NUM >= 150000 )) || die "Mattermost 12 vyžaduje PostgreSQL 15+"
	(( tmaj == cmaj )) || warn "major upgrade $cmaj -> $tmaj: přečti si $NOTES_URL"

	local name=mattermost
	[[ $EDITION == team ]] && name=mattermost-team
	TARBALL=$name-$TARGET-linux-amd64.tar.gz
	URL=$RELEASES/$TARGET/$TARBALL
	TAR_BYTES=$(curl -fsSI -m 20 "$URL" | awk 'tolower($1) == "content-length:" {print $2}' | tr -d '\r') ||
		die "tarball neexistuje: $URL"
	[[ $TAR_BYTES =~ ^[0-9]+$ ]] && (( TAR_BYTES > 100000000 )) || die "podezřelá velikost tarballu: ${TAR_BYTES:-?}"
	curl -fsSI -m 20 "$URL.sha256" >/dev/null || die "chybí kontrolní součet $URL.sha256"
	ok "ke stažení: $URL ($((TAR_BYTES / 1024 / 1024)) MB)"

	local parent anc keep_kb=0 p avail_kb need_kb
	parent=$(dirname "$MM_DIR")
	anc=$BACKUP_ROOT
	while [[ ! -d $anc ]]; do anc=$(dirname "$anc"); done
	[[ $(stat -c %d "$parent") == $(stat -c %d "$anc") ]] ||
		die "$BACKUP_ROOT není na stejném filesystému jako $parent (výměna musí být atomický mv)"
	for p in "${KEEP_TOP[@]}" client/plugins "${EXTRA_CFG[@]}"; do
		[[ -e $MM_DIR/$p ]] && keep_kb=$((keep_kb + $(du -sk "$MM_DIR/$p" | cut -f1)))
	done
	avail_kb=$(df -k --output=avail "$parent" | tail -1 | tr -d ' ')
	need_kb=$((TAR_BYTES * 3 / 1024 + keep_kb + DB_BYTES / 1024 + MARGIN_KB))
	(( avail_kb > need_kb )) || die "málo místa na $parent: volno $((avail_kb / 1024)) MB, potřeba $((need_kb / 1024)) MB"
	ok "místo: volno $((avail_kb / 1024 / 1024)) GB, potřeba ~$((need_kb / 1024 / 1024)) GB (data+config+logy+pluginy $((keep_kb / 1024)) MB)"

	local stale
	stale=$(find "$parent" -maxdepth 1 -name '.mattermost-stage.*' -print -quit)
	[[ -z $stale ]] || die "zbytek po minulém běhu: $stale (prohlédni a smaž)"
	if [[ -e $MM_DIR/client/plugins ]]; then
		log "pluginy (po major upgradu zkontroluj System Console > Plugins): $(ls "$MM_DIR/plugins" | tr '\n' ' ')"
	fi
}

do_upgrade() {
	preflight "$1"
	local parent
	parent=$(dirname "$MM_DIR")

	log "== 1/7 stahuju a ověřuju (služba běží dál) =="
	STAGE=$(mktemp -d "$parent/.mattermost-stage.XXXXXX")
	chmod 711 "$STAGE"
	curl -fL --retry 3 --retry-delay 5 -o "$STAGE/$TARBALL" "$URL"
	[[ $(stat -c %s "$STAGE/$TARBALL") == "$TAR_BYTES" ]] || die "stažený soubor má jinou velikost než Content-Length"
	local want_sum got_sum
	want_sum=$(curl -fsS -m 20 "$URL.sha256" | awk 'NR == 1 {print $1}')
	[[ $want_sum =~ ^[0-9a-f]{64}$ ]] || die "nerozumím souboru .sha256"
	got_sum=$(sha256sum "$STAGE/$TARBALL" | awk '{print $1}')
	[[ $want_sum == "$got_sum" ]] || die "sha256 nesedí: čekal jsem $want_sum, mám $got_sum"
	ok "sha256 sedí ($got_sum)"

	tar -tzf "$STAGE/$TARBALL" >"$STAGE/list"
	if grep -qvE '^mattermost/' "$STAGE/list" || grep -qE '(^|/)\.\.(/|$)' "$STAGE/list"; then
		die "tarball obsahuje cesty mimo mattermost/"
	fi
	tar -xzpf "$STAGE/$TARBALL" --no-same-owner -C "$STAGE"
	rm -f -- "$STAGE/$TARBALL"
	local new=$STAGE/mattermost
	[[ -x $new/bin/mattermost && -d $new/client && -d $new/i18n && -d $new/templates ]] || die "rozbalený tarball nevypadá jako Mattermost"
	[[ $(awk -F= '$1 == "EDITION" {print $2}' "$new/manifest.txt") == "$EDITION" ]] || die "tarball je jiná edice než $EDITION"
	ok "rozbaleno do $new"

	local carry=("${KEEP_TOP[@]}") e known
	for e in "${EXTRA_CFG[@]}"; do carry+=("${e%%/*}"); done
	while IFS= read -r e; do
		[[ -e $new/$e ]] && continue
		known=0
		for p in "${carry[@]}"; do [[ $p == "$e" ]] && known=1; done
		if [[ $known == 0 ]]; then
			warn "v $MM_DIR je navíc '$e' (není v tarballu); přenesu ho do nové instalace"
			carry+=("$e")
		fi
	done < <(find "$MM_DIR" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
	mapfile -t carry < <(printf '%s\n' "${carry[@]}" | sort -u)

	local stamp
	stamp=$(date +%F-%H%M%S)
	BK=$BACKUP_ROOT/${stamp}_$CUR_VER
	confirm ano "Připraveno: $CUR_VER -> $TARGET ($EDITION), varování: $WARNINGS.
Teď ZASTAVÍM $UNIT, udělám pg_dump $DB_NAME, zkopíruju ${carry[*]} + client/plugins,
starou instalaci přesunu do $BK/mattermost a pustím novou. Výpadek = doba kopírování + migrace DB."

	log "== 2/7 zastavuju $UNIT =="
	( umask 077; mkdir -p "$BK" )
	systemctl stop "$UNIT"
	PHASE=stopped
	wait_stopped
	[[ -z $(ss -ltnH "sport = :$MM_PORT") ]] || die "port $MM_PORT je po zastavení stále obsazený"
	ok "služba stojí, žádný proces $RUN_USER, port $MM_PORT volný"

	log "== 3/7 záloha DB =="
	local i conns=1
	for i in $(seq 1 15); do
		conns=$(pg -d postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '$DB_NAME'")
		[[ $conns == 0 ]] && break
		sleep 2
	done
	[[ $conns == 0 ]] || die "do DB $DB_NAME je stále připojeno $conns klientů (běží záloha? jiná aplikace?)"
	( umask 077; runuser -u postgres -- pg_dump -p "$DB_PORT" -Fc "$DB_NAME" >"$BK/db.dump" )
	[[ -s $BK/db.dump ]] || die "pg_dump je prázdný"
	local dumped tables
	dumped=$(pg_restore -l "$BK/db.dump" | grep -c ' TABLE DATA ') || die "pg_dump nejde přečíst zpět (pg_restore -l)"
	tables=$(pg -d "$DB_NAME" -c "SELECT count(*) FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema')")
	(( dumped > 0 )) || die "pg_dump neobsahuje žádná data tabulek"
	[[ $dumped == "$tables" ]] || warn "dump má $dumped tabulek s daty, DB jich má $tables"
	( cd "$BK" && sha256sum db.dump >db.dump.sha256 )
	ok "pg_dump: $BK/db.dump ($(du -h "$BK/db.dump" | cut -f1), $dumped tabulek)"

	log "== 4/7 kopíruju data do nové instalace (stará zůstává netknutá) =="
	rm -rf -- "$new/config" "$new/logs"
	local p src dst
	for p in "${carry[@]}" client/plugins; do
		src=$MM_DIR/$p
		dst=$new/$p
		[[ -e $src ]] || { log "  $p: ve staré instalaci není, přeskakuju"; continue; }
		[[ ! -e $dst ]] || die "$p už v nové instalaci existuje, nepřepisuju"
		cp -a --reflink=auto -- "$src" "$dst"
		if [[ -d $src ]]; then
			[[ $(tree_sig "$src") == "$(tree_sig "$dst")" ]] || die "kopie $p nesedí (počet souborů / bajtů)"
		else
			cmp -s "$src" "$dst" || die "kopie $p nesedí"
		fi
		ok "  $p zkopírováno a ověřeno"
	done
	cmp -s "$CFG" "$new/config/config.json" || die "config.json v nové instalaci se liší od původního"
	chown -hR "$RUN_USER:$RUN_GROUP" "$new"
	if command -v getcap >/dev/null && [[ -n $(getcap "$MM_DIR/bin/mattermost") ]]; then
		setcap "$(getcap "$MM_DIR/bin/mattermost" | awk '{print $NF}')" "$new/bin/mattermost"
	elif (( MM_PORT < 1024 )); then
		die "server poslouchá na portu $MM_PORT < 1024 a nemám getcap/setcap"
	fi

	log "== 5/7 zkouším novou binárku =="
	local staged_ver
	staged_ver=$(mm_version_of "$new")
	[[ $staged_ver == "$TARGET" ]] || die "nová binárka hlásí '${staged_ver:-nic}' místo $TARGET (glibc? poškozený tarball?)"
	ok "nová binárka běží a hlásí $staged_ver"

	log "== 6/7 výměna =="
	cat >"$BK/info" <<EOF
from=$CUR_VER
to=$TARGET
edition=$EDITION
db_name=$DB_NAME
db_port=$DB_PORT
date=$stamp
EOF
	mv -T -- "$MM_DIR" "$BK/mattermost"
	if ! mv -T -- "$new" "$MM_DIR"; then
		mv -T -- "$BK/mattermost" "$MM_DIR"
		die "výměna selhala, stará instalace vrácena na místo"
	fi
	PHASE=swapped
	ok "stará instalace: $BK/mattermost, nová: $MM_DIR"

	log "== 7/7 start a kontrola (migrace DB mohou trvat) =="
	local restarts_before
	systemctl start "$UNIT" || die "systemctl start $UNIT selhal"
	restarts_before=$(systemctl show "$UNIT" -p NRestarts --value)
	local live=""
	for i in $(seq 1 60); do
		live=$(ping_version) && break
		sleep 2
	done
	[[ $live == "$TARGET" ]] || die "health check po startu: čekal jsem $TARGET, dostal '${live:-bez odpovědi}'"
	sleep 20
	systemctl is-active --quiet "$UNIT" || die "$UNIT po 20 s neběží"
	[[ $(systemctl show "$UNIT" -p NRestarts --value) == "$restarts_before" ]] || die "$UNIT se restartuje (crash loop)"
	[[ $(ping_version) == "$TARGET" ]] || die "druhý health check selhal"
	PHASE=done
	ok "Mattermost $TARGET běží, health check OK"
	journalctl -u "$UNIT" --since "-3min" --no-pager -q | grep -iE '"level":"(error|fatal)"|panic' | tail -15 || true
	cat <<EOF

HOTOVO: $CUR_VER -> $TARGET (varování: $WARNINGS)
  záloha:    $BK  (aplikace + data + db.dump)
  rollback:  $0 rollback $BK
  ručně:     přihlas se, pošli zprávu, otevři soubor, System Console > Plugins
  úklid:     až budeš spokojený, smaž $BK
EOF
}

do_rollback() {
	load_install
	BK=${1:-}
	if [[ -z $BK ]]; then
		BK=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' | sort | tail -1)
	fi
	[[ -n $BK && -d $BK ]] || die "záloha nenalezena"
	BK=$(realpath "$BK")
	[[ -x $BK/mattermost/bin/mattermost && -s $BK/db.dump && -s $BK/info ]] || die "$BK není úplná záloha"
	( cd "$BK" && sha256sum --quiet -c db.dump.sha256 ) || die "db.dump neodpovídá kontrolnímu součtu"
	local from to bk_db bk_port
	from=$(awk -F= '$1 == "from" {print $2}' "$BK/info")
	to=$(awk -F= '$1 == "to" {print $2}' "$BK/info")
	bk_db=$(awk -F= '$1 == "db_name" {print $2}' "$BK/info")
	bk_port=$(awk -F= '$1 == "db_port" {print $2}' "$BK/info")
	[[ $bk_db == "$DB_NAME" && $bk_port == "$DB_PORT" ]] || die "záloha je z jiné DB ($bk_db:$bk_port) než dnešní config ($DB_NAME:$DB_PORT)"
	pg_restore -l "$BK/db.dump" >/dev/null || die "db.dump nejde přečíst"

	local stamp failed_db failed_dir avail_kb need_kb
	stamp=$(date +%Y%m%d%H%M%S)
	failed_db=${DB_NAME}_failed_$stamp
	failed_dir=$BACKUP_ROOT/failed-${stamp}_$to
	avail_kb=$(df -k --output=avail "$(dirname "$MM_DIR")" | tail -1 | tr -d ' ')
	need_kb=$(( $(du -sk "$BK/mattermost" | cut -f1) + MARGIN_KB ))
	(( avail_kb > need_kb )) || die "málo místa na rollback"

	confirm rollback "ROLLBACK na $from ze zálohy $BK.
Vše, co uživatelé napsali a nahráli od upgradu, z běžícího systému ZMIZÍ
(zůstane v DB $failed_db a v $failed_dir)."

	PHASE=rollback
	systemctl stop "$UNIT"
	wait_stopped
	pg -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME'" >/dev/null

	local tmp
	tmp=$(dirname "$MM_DIR")/.mattermost-restore.$stamp
	cp -a --reflink=auto -- "$BK/mattermost" "$tmp"
	[[ $(tree_sig "$BK/mattermost") == "$(tree_sig "$tmp")" ]] || die "kopie zálohy nesedí"
	( umask 077; mkdir -p "$failed_dir" )
	mv -T -- "$MM_DIR" "$failed_dir/mattermost"
	mv -T -- "$tmp" "$MM_DIR"
	ok "aplikace vrácena, nepovedená verze je v $failed_dir/mattermost"

	pg -d postgres -c "ALTER DATABASE \"$DB_NAME\" RENAME TO \"$failed_db\"" >/dev/null
	if ! runuser -u postgres -- pg_restore -p "$DB_PORT" -C -d postgres --exit-on-error <"$BK/db.dump"; then
		die "pg_restore selhal; původní DB je pod jménem $failed_db (vrátíš ji: ALTER DATABASE ... RENAME TO $DB_NAME)"
	fi
	ok "DB $DB_NAME obnovena z dumpu, nepovedená je $failed_db"

	systemctl start "$UNIT" || die "systemctl start $UNIT selhal"
	local i live=""
	for i in $(seq 1 60); do
		live=$(ping_version) && break
		sleep 2
	done
	[[ $live == "$from" ]] || die "po rollbacku čekám $from, health check vrací '${live:-bez odpovědi}'"
	PHASE=done
	ok "rollback hotový, běží $from"
	log "úklid ručně: DROP DATABASE \"$failed_db\"; rm -rf $failed_dir"
}

args=()
for a in "$@"; do
	case $a in
	--yes) ASSUME_YES=1 ;;
	--force-jump) FORCE_JUMP=1 ;;
	-h | --help) usage; exit 0 ;;
	-*) usage >&2; exit 2 ;;
	*) args+=("$a") ;;
	esac
done
cmd=${args[0]:-}
[[ -n $cmd ]] || { usage >&2; exit 2; }

case $cmd in
list)
	ls -ld "$BACKUP_ROOT"/*/ 2>/dev/null || echo "žádné zálohy v $BACKUP_ROOT"
	exit 0 ;;
check | upgrade | rollback) ;;
*) usage >&2; exit 2 ;;
esac

[[ $EUID == 0 ]] || die "pusť pod rootem (sudo)"
exec 9>/run/lock/mattermost-upgrade.lock
flock -n 9 || die "jiný běh mattermost-upgrade už běží"
LOG=/var/log/mattermost-upgrade-$(date +%F-%H%M%S).log
exec > >(tee -a "$LOG") 2>&1
trap on_exit EXIT
log "log: $LOG"

case $cmd in
check)
	preflight "${args[1]:-latest}"
	log "kontroly prošly ($CUR_VER -> $TARGET, varování: $WARNINGS); nic jsem nezměnil" ;;
upgrade)
	[[ -n ${args[1]:-} ]] || die "chybí verze: $0 upgrade X.Y.Z|latest"
	do_upgrade "${args[1]}" ;;
rollback)
	do_rollback "${args[1]:-}" ;;
esac
