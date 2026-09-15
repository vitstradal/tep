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

## 2. Deployment — vlastní `sklepox` session (JEDINÝ zdroj pravdy)

> ⚠️ **NEinstalovat OxiCloud z tep repa.** Dřívější `script/install-oxicloud.sh`
> (make install-oxicloud) stavěl z upstream klonu BEZ base-path podpory a
> 2026-09-15 tím přepsal funkční deployment → /sklepox servíroval root
> assety. Skript je odstraněný. Tep repo drží k OxiCloudu jen OIDC klienta
> (`rake oidc:register`) a root `.well-known` DAV redirect.

Nasazení (build i deploy) vlastní `sklepox` session; toto je referenční popis:

- **Zdroj buildu:** `/home/vitas/git/OxiCloud`, větev `vitas` (base-path
  podpora; origin = upstream AtalayaLabs/OxiCloud). NE `~vitas/build/OxiCloud`
  (to je čistý upstream bez base-path — právě ten to rozbil).
- **Build:** `docker build --build-arg PUBLIC_BASE_PATH=/sklepox`
  (musl static-pie, přenositelné). `PUBLIC_BASE_PATH` se vkompilovává do
  frontendu → změna prefixu = rebuild.
- **Deploy:** staging `~/oxicloud/` + `sudo bash ~/oxicloud/update.sh`
  (běžný upgrade) / `repair-sklepox.sh` (náprava). Skripty žijí v `~/oxicloud`.
- **Layout:** `/opt/oxicloud/{bin/oxicloud,static}`,
  `/etc/oxicloud/oxicloud.env` (640 root:oxicloud), `/var/lib/oxicloud`,
  unit `oxicloud.service` (User=oxicloud, hardened). Server :8086 loopback.
- **Prefix — dva knoby:** runtime `OXICLOUD_BASE_PATH=/sklepox` (env) +
  build-time `PUBLIC_BASE_PATH=/sklepox` (frontend). Server při bootu
  porovná env s meta v index.html a při neshodě odmítne start.
- **Apache:** `ProxyPass /sklepox http://127.0.0.1:8086/sklepox`
  (BEZ trailing slash cíle — jinak padá DPoP na wrong_htu), upgrade=websocket.
- **DB:** momentálně `oxicloud` na PG17 :5435 (rename na `sklepox_db` čeká na
  přímé Vítovo potvrzení ve vlákně sklepox). Storage `/var/lib/oxicloud`.

## 3. OIDC přihlášení přes tep (přístup pro orgy)

1. Tep issuer `https://pikomat.mff.cuni.cz` (bez lomítka), OIDC vrstva
   hotová (discovery, id_token, userinfo, groups claim org/admin).
2. Registrace klienta (na prod tepu):
   `make prod-oidc-register NAME=oxicloud REDIRECT_URI=https://pikomat.mff.cuni.cz/sklepox/api/auth/oidc/callback`
   → vypíše client_id/secret.
3. Ty dvě hodnoty + OIDC blok do `/etc/oxicloud/oxicloud.env`
   (`OXICLOUD_OIDC_ENABLED=true`, ISSUER_URL, REDIRECT_URI, SCOPES
   `openid profile email`, `OXICLOUD_OIDC_ADMIN_GROUPS=admin`), restart oxicloud.
4. Přístup gatuje tep jen orgům (`resource_owner_authenticator`); tep-admini
   dostanou přes groups claim admina v OxiCloudu.
5. CalDAV/CardDAV autodiscovery: tep na kořeni redirectuje
   `/.well-known/caldav|carddav` → `/sklepox/{caldav,carddav}/` (RFC 6764).

## 4. Pilotní checklist (z čeho se rozhodne o migraci sklepu)

- [ ] upload/download větších souborů (GB fotky z táborů)
- [ ] WebDAV: mount + rclone sync (náhrada NC desktop klienta!)
- [ ] CalDAV: založit kalendář, připojit Thunderbird/DAVx5, pikoorg-cal
- [ ] sdílecí odkazy (obdoba NC share links)
- [ ] kvóty, admin správa uživatelů
- [ ] výkon na 25 GB metadat / 100 GB souborů (zkušební rsync části sklepu)
- [ ] zálohy: DB dump (pikomat-zaloha.py ji vezme automaticky) + storage
      adresář (přidat /home/www/oxicloud-data do zálohy, až bude ostrý)


## 5. OIDC pres tep (doplneno 2026-09-13)

Tep umi od 2026-09-13 plne OIDC (gem `doorkeeper-openid_connect`):
discovery na `/.well-known/openid-configuration`, id_token, userinfo.
OAuth pousti jen org uzivatele (resource_owner_authenticator).

Nasazeni na serveru (v /home/www/rails/tep):

```sh
bundle install
rails db:migrate
make gen-oidc-signing-key   # config/oidc_signing_key.pem (gitignored)
make restart
```

Registrace klienta: jako tep admin na /oauth/applications zalozit
aplikaci "OxiCloud":
  - Redirect URI: https://pikomat.mff.cuni.cz/oxicloud/api/auth/oidc/callback
  - Scopes: openid profile email
  - Confidential: ano

OxiCloud (/etc/oxicloud/oxicloud.env, pak systemctl restart oxicloud):

```sh
OXICLOUD_OIDC_ENABLED=true
OXICLOUD_OIDC_ISSUER_URL=https://pikomat.mff.cuni.cz
OXICLOUD_OIDC_CLIENT_ID=<uid z /oauth/applications>
OXICLOUD_OIDC_CLIENT_SECRET=<secret z /oauth/applications>
OXICLOUD_OIDC_REDIRECT_URI=https://pikomat.mff.cuni.cz/oxicloud/api/auth/oidc/callback
OXICLOUD_OIDC_FRONTEND_URL=https://pikomat.mff.cuni.cz/oxicloud
OXICLOUD_OIDC_PROVIDER_NAME=TEP
```

Admini v OxiCloudu se spravuji rucne (zadny groups claim se nemapuje).
