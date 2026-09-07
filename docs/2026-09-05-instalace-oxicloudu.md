# Instalace OxiCloudu na pikomatu (runbook)

Datum: 2026-09-05. Pilot dle světlých zítřků (etapa 2); kompiluje se přímo
na serveru — binárka tak přesně sedí na glibc a přežije i plánovaný
dist-upgrade (glibc jen poroste).

## Fakta o OxiCloudu (stav 9/2026, repo AtalayaLabs/OxiCloud)

- Rust (axum) + **PostgreSQL** (povinný), frontend SvelteKit → statické
  soubory v `static-dist/`, servírované binárkou.
- Umí: WebDAV, **CalDAV/CardDAV**, OIDC/SSO, JWT auth (Argon2id), kvóty,
  volitelně WOPI (Collabora). Chybí: vlastní desktop sync klient (sync =
  WebDAV klienti/rclone) a mobilní app.
- v0.8.9 bez release binárek → build ze zdrojáků; Rust ≥ 1.93, node ≥ 20.
- Konfigurace env proměnnými (`example.env`): `OXICLOUD_SERVER_HOST/PORT`,
  `OXICLOUD_STORAGE_PATH`, `OXICLOUD_DB_CONNECTION_STRING`,
  `OXICLOUD_JWT_SECRET`, `OXICLOUD_OIDC_*`, `OXICLOUD_ENABLE_AUTH`…
  Admin účet vzniká přes `POST /api/setup` při prvním spuštění.

## 1. Toolchain a build (bez roota, hotovo 2026-09-05)

Provedeno pod `vitas` na pikomatu:

```sh
# rustup (stable, ~/.cargo, ~/.rustup) — rustc 1.98.1
curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
# node 22 tarball (systémový node v8 je nepoužitelný) -> ~/opt/node
mkdir -p ~/opt && cd ~/opt \
  && curl -sSLo node.tar.xz https://nodejs.org/dist/v22.15.0/node-v22.15.0-linux-x64.tar.xz \
  && tar xf node.tar.xz && mv node-v22.15.0-linux-x64 node && rm node.tar.xz
# zdrojáky
mkdir -p ~/build && cd ~/build \
  && git clone --depth 1 https://github.com/AtalayaLabs/OxiCloud.git
# build (viz ~/build/OxiCloud/build.sh; log v build.log):
#   frontend: npm ci && npm run build   -> ../static-dist/
#   backend:  cargo build --release -j2 (nice -19, šetrné k produkci)
```

Výsledek: `~/build/OxiCloud/target/release/oxicloud` + `~/build/OxiCloud/static-dist/`.
Rebuild po `git pull`: spustit znovu `./build.sh`.

## 2. Instalace do /opt (root)

```sh
# uživatel a adresáře
useradd --system --home /var/lib/oxicloud --shell /usr/sbin/nologin oxicloud
mkdir -p /opt/oxicloud /etc/oxicloud /var/lib/oxicloud/tmp
# data na RAID (/home, 791 GB volných) — sem poputuje obsah sklepu
mkdir -p /home/www/oxicloud-data
chown oxicloud:oxicloud /var/lib/oxicloud /var/lib/oxicloud/tmp /home/www/oxicloud-data

# binárka + statika
install -m 755 ~vitas/build/OxiCloud/target/release/oxicloud /opt/oxicloud/oxicloud
cp -r ~vitas/build/OxiCloud/static-dist /opt/oxicloud/static-dist

# databáze na PG17 (:5435)
sudo -u postgres createuser -p 5435 oxicloud
sudo -u postgres createdb   -p 5435 -O oxicloud oxicloud
sudo -u postgres psql -p 5435 -c "ALTER USER oxicloud PASSWORD '<vygeneruj>'"
```

`/etc/oxicloud/oxicloud.env` (práva 640, root:oxicloud):

```sh
OXICLOUD_SERVER_HOST=127.0.0.1
OXICLOUD_SERVER_PORT=8086
OXICLOUD_BASE_URL=https://pikomat.mff.cuni.cz/oxisklep
OXICLOUD_STORAGE_PATH=/home/www/oxicloud-data
OXICLOUD_STATIC_PATH=/opt/oxicloud/static-dist
OXICLOUD_TEMP_DIR=/var/lib/oxicloud/tmp
OXICLOUD_DB_CONNECTION_STRING=postgres://oxicloud:<heslo>@localhost:5435/oxicloud
DATABASE_URL=postgres://oxicloud:<heslo>@localhost:5435/oxicloud
OXICLOUD_JWT_SECRET=<openssl rand -hex 32>
OXICLOUD_ENABLE_AUTH=true
MIMALLOC_PURGE_DELAY=0
```

`/etc/systemd/system/oxicloud.service` (vzor afterleaf):

```ini
[Unit]
Description=OxiCloud — souborove uloziste (pilot /oxisklep)
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
```

```sh
systemctl daemon-reload && systemctl enable --now oxicloud
curl -s http://127.0.0.1:8086/ | head -3     # žije?
```

## 3. První kroky po startu

1. Admin účet: `POST /api/setup` (UI to nabídne při prvním otevření).
2. Pilotní přístup bez Apache: `ssh -L 8086:127.0.0.1:8086 pikomat...`
   → http://localhost:8086/.
3. **Ověřit chování pod subcestou** (`OXICLOUD_BASE_URL=…/oxisklep`) —
   pokud SPA subpath neunese, pilot zůstane na tunelu a veřejná expozice
   se vyřeší až s vlastním jménem/portem (otevřená otázka pilotu č. 1).
4. Apache (root, až subpath ověřen):
   `ProxyPass /oxisklep http://127.0.0.1:8086/` + ProxyPassReverse.
5. Auth: začít lokálními účty; OIDC nechat vypnuté (tep OIDC neumí —
   rozhodnuto žít s Doorkeeper OAuth2; jestli OxiCloud umí jen čisté
   OIDC, je tohle druhá otevřená otázka pilotu — případně tenká proxy).

## 4. Pilotní checklist (z čeho se rozhodne o migraci sklepu)

- [ ] upload/download větších souborů (GB fotky z táborů)
- [ ] WebDAV: mount + rclone sync (náhrada NC desktop klienta!)
- [ ] CalDAV: založit kalendář, připojit Thunderbird/DAVx5, pikoorg-cal
- [ ] sdílecí odkazy (obdoba NC share links)
- [ ] kvóty, admin správa uživatelů
- [ ] výkon na 25 GB metadat / 100 GB souborů (zkušební rsync části sklepu)
- [ ] zálohy: DB dump (pikomat-zaloha.py ji vezme automaticky) + storage
      adresář (přidat /home/www/oxicloud-data do zálohy, až bude ostrý)
