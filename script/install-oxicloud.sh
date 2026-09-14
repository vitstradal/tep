#!/bin/bash
##
# install-oxicloud.sh — instalace/upgrade OxiCloudu na pikomatu (pod rootem).
#
# Idempotentní: první běh založí uživatele, DB (sklepox_db na PG17 :5435),
# vygeneruje secrety a napíše konfig + systemd unit. Další běh je UPGRADE —
# jen přeinstaluje binárku/statiku z buildu a restartuje; konfig a secrety
# (/etc/oxicloud/oxicloud.env) nechává být.
#
# Předpoklad: build pod vitasem hotový (script/build.sh v ~vitas/build/OxiCloud;
# binárka target/release/oxicloud + static-dist/). Verzi ukáže --version.
#
# Pilotní volby (viz docs/2026-09-05-instalace-oxicloudu.md): lokální účty
# (OIDC vypnuté), přístup jen ssh tunelem (bez Apache; OxiCloud neumí subcestu).
#
# Použití:  install-oxicloud.sh
# Přístup po startu:  ssh -L 8086:127.0.0.1:8086 pikomat...  → http://localhost:8086/

set -euo pipefail

BUILD_DIR=${BUILD_DIR:-/home/vitas/build/OxiCloud}
PGPORT=${PGPORT:-5435}
PORT=${PORT:-8086}
ENV_FILE=/etc/oxicloud/oxicloud.env
DATA_DIR=/home/www/oxicloud-data

log() { echo "[install-oxicloud] $*"; }

[ "$(id -u)" = 0 ] || { echo "spust pod rootem"; exit 1; }
[ -x "$BUILD_DIR/target/release/oxicloud" ] || {
  echo "chybi binárka $BUILD_DIR/target/release/oxicloud (nejdřív ./build.sh pod vitasem)"; exit 1; }
[ -d "$BUILD_DIR/static-dist" ] || { echo "chybi $BUILD_DIR/static-dist"; exit 1; }

# --- uživatel a adresáře -------------------------------------------------
if ! id oxicloud >/dev/null 2>&1; then
  log "zakládám systémového uživatele oxicloud"
  useradd --system --home /var/lib/oxicloud --shell /usr/sbin/nologin oxicloud
fi
mkdir -p /opt/oxicloud /etc/oxicloud /var/lib/oxicloud/tmp "$DATA_DIR"
chown oxicloud:oxicloud /var/lib/oxicloud /var/lib/oxicloud/tmp "$DATA_DIR"

# --- binárka + statika (vždy — tohle je i upgrade cesta) -----------------
VERZE=$("$BUILD_DIR/target/release/oxicloud" --version 2>&1 | head -1)
log "instaluji $VERZE"
# běžící proces drží starý inode, výměna souboru je bezpečná; restart níže
install -m 755 "$BUILD_DIR/target/release/oxicloud" /opt/oxicloud/oxicloud
rm -rf /opt/oxicloud/static-dist
cp -r "$BUILD_DIR/static-dist" /opt/oxicloud/static-dist

# --- databáze sklepox_db na PG17 -----------------------------------------
psql_pg() { sudo -u postgres psql -p "$PGPORT" -tAc "$1"; }
if [ "$(psql_pg "SELECT 1 FROM pg_roles WHERE rolname='sklepox'")" != 1 ]; then
  log "zakládám PG uživatele sklepox na :$PGPORT"
  sudo -u postgres createuser -p "$PGPORT" sklepox
fi
if [ "$(psql_pg "SELECT 1 FROM pg_database WHERE datname='sklepox_db'")" != 1 ]; then
  log "zakládám DB sklepox_db"
  sudo -u postgres createdb -p "$PGPORT" -O sklepox sklepox_db
fi

# --- konfig + secrety (jen napoprvé; upgrade je nemění) -------------------
if [ ! -f "$ENV_FILE" ]; then
  log "generuji secrety a píšu $ENV_FILE"
  JWT=$(openssl rand -hex 32)
  DBPASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
  sudo -u postgres psql -p "$PGPORT" -c "ALTER USER sklepox PASSWORD '$DBPASS'" >/dev/null
  umask 027
  cat > "$ENV_FILE" <<EOF
OXICLOUD_SERVER_HOST=127.0.0.1
OXICLOUD_SERVER_PORT=$PORT
OXICLOUD_BASE_URL=http://localhost:$PORT
OXICLOUD_STORAGE_PATH=$DATA_DIR
OXICLOUD_STATIC_PATH=/opt/oxicloud/static-dist
OXICLOUD_TEMP_DIR=/var/lib/oxicloud/tmp
OXICLOUD_DB_CONNECTION_STRING=postgres://sklepox:$DBPASS@localhost:$PGPORT/sklepox_db
DATABASE_URL=postgres://sklepox:$DBPASS@localhost:$PGPORT/sklepox_db
OXICLOUD_JWT_SECRET=$JWT
OXICLOUD_ENABLE_AUTH=true
OXICLOUD_OIDC_ENABLED=false
MIMALLOC_PURGE_DELAY=0
EOF
  chown root:oxicloud "$ENV_FILE"
  chmod 640 "$ENV_FILE"
else
  log "$ENV_FILE už existuje — nechávám (secrety zachovány)"
fi

# --- systemd unit --------------------------------------------------------
log "píšu systemd unit"
cat > /etc/systemd/system/oxicloud.service <<'EOF'
[Unit]
Description=OxiCloud — souborove uloziste (pilot, ssh tunel)
After=network.target postgresql.service

[Service]
Type=simple
User=oxicloud
Group=oxicloud
EnvironmentFile=/etc/oxicloud/oxicloud.env
WorkingDirectory=/opt/oxicloud
ExecStart=/opt/oxicloud/oxicloud
Restart=on-failure
RestartSec=2s
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=/var/lib/oxicloud /home/www/oxicloud-data

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable oxicloud >/dev/null 2>&1 || true
systemctl restart oxicloud

# --- health check --------------------------------------------------------
log "čekám na start..."
for i in $(seq 1 15); do
  if curl -sf -o /dev/null "http://127.0.0.1:$PORT/"; then
    log "OK — OxiCloud běží na 127.0.0.1:$PORT ($VERZE)"
    log "přístup: ssh -L $PORT:127.0.0.1:$PORT pikomat...  →  http://localhost:$PORT/"
    log "první admin účet: otevři UI, nabídne POST /api/setup"
    exit 0
  fi
  sleep 2
done
log "VAROVÁNÍ: služba se do 30 s neozvala — mrkni: journalctl -u oxicloud -n 40"
exit 1
