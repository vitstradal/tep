# Přehled pikomatího serveru a ekosystému

Datum: 2026-08-29. Zdroje: repa `~/git/tep`, `~/git/pikusy`, lokální obraz
sklepu `~/sklep/pikomat`, a živý server `pikomat.mff.cuni.cz` (neprivilegovaný
SSH průzkum: procesy, porty, apache vhost, systemd, aliasy). Cíl: inventura
před přestavbou — silný rychlý server s jednotnou autentizací.

## 1. Železo a systém

- Debian **trixie/sid**, kernel 6.12 (bpo), 4 CPU, **7,7 GB RAM**, disky:
  `/` 886 GB (19 %), `/home` RAID `md0` 1,8 TB (55 %, z toho sklep data).
- **Uptime 382 dní** — běží stabilně, ale znamená to rok bez rebootu/kernelu.
- PostgreSQL: **15 (:5432, tep)** a **17 (:5435)** online; clustery 9.4, 9.6,
  11, 13 mrtvé (binárky pryč, datové adresáře zůstaly).
- Mail: postfix + dovecot (IMAP schránky orgů = účty v `/home`, ~70 účtů),
  opendkim/openarc, mailman3.
- Docker (overleaf), Passenger v Apache (tep), Collabora `coolwsd`.

## 2. Mapa URL a služeb (Apache vhost)

| URL | Co | Technologie | Autentizace | Stav |
|---|---|---|---|---|
| `/` | **tep** — web, wiki, sosna (řešitelé), act (akce), kvízy/friend | Rails 7.2, Passenger, PG15 | Devise; **OAuth provider (Doorkeeper)** pro ostatní | jádro všeho |
| `/wikuk`, `/webed`, `/dataed`… | wiki (giwi) — obsahy v `~/git/{web,piki,tepmac}` na serveru | git-backed wiki v tepu | role z tepu (anon/org/morg) | aktivní |
| `/sklep` | **sklep** = Nextcloud **30.0.11** | PHP 8.4 | Nextcloud login flow → tep (social login, účty `tep-…`) | aktivní, 105+ GB dat |
| `/cool`, `/browser` | Collabora Online (dokumenty ve sklepu) | coolwsd :9980 | přes sklep | aktivní |
| `/klep` | **klep** = Mattermost | Go :8065, PG | „GitLab" SSO → **tep Doorkeeper** | aktivní |
| `/preklep` | **Overleaf CE** | docker (node ×12, mongo, vlastní nginx :2081/:20443) | **vlastní účty — NEnapojeno na tep (největší bolest)** | aktivní; v `/home/www/overleaf` leží soubor `CRASH` |
| `/pub/herna/` | herna (realtime hry, pikviz) | Rust/axum :31415, user `marvin`, z `~/git/herna` | tokeny herny; obsah přes tep neautorizuje | aktivní |
| `/pub/prednasky` `/pub/bleskarty` `/pub/pikoraptor` `/pub/tep-foto` | statické frontendy z pikusy | rsync `dist/` | prednasky+tep-foto přes tep (csrf/friend); zbytek bez auth | aktivní |
| `/mailman3` | mailing listy | mailman3 + uwsgi | vlastní (mailman) | **mrtvé** (service failed, routing vypnutý) |
| `/fotky`, `/html`, `/ovvp` | statika | Apache | bez auth | ? |
| `/provedouci` | statika pro vedoucí | Apache | **htpasswd** (mimo tep) | ? |
| `/tep-dev` | dev instance tepu | Rails, ruby 3.3.6, RackEnv development | htpasswd + Devise | testovací |
| `/kartana/souboj-bazin` | Rails app „kartic" | Rails, development mode! | htpasswd | **neznámé — viz otázky** |
| `/saman` | osobní www Honzy (`/home/honza/www`) | statika | bez auth | **neznámé — viz otázky** |
| *(neexponováno)* | **afterleaf** — LaTeX server | Rust/axum, `127.0.0.1:3000`, systemd `afterleaf.service`, user `afterleaf` | OIDC připraveno, **teď `mode = "disabled"`** | **běží, ale není v Apache — nedostupný zvenku** |

Na localhostu dále: `:33233` (odpovídá „missing connection token" — vypadá
jako code-server/openvscode; **neidentifikováno**), `:42653` (nic nevrací,
zřejmě interní port Mattermostu/dockeru).

Mailové adresy — tři historické vrstvy, z nichž žije jen poslední:
1. **majordomo** (`/etc/postfix/majordomo.aliases`) — celé zakomentované, mrtvé;
2. **mailman3** — služba `failed`, web `inactive`, postfix routing v `main.cf`
   **zakomentovaný**; definice listů (tabor@, soustredeni@, …) v
   `/var/lib/mailman3` jen leží. **Mailman nic neobsluhuje** (potvrzeno,
   už se neprovozuje) — enabled služby jen dělají error noise, vypnout;
3. **živý stav**: akční adresy = **unixoví uživatelé** (`/home/tabor`,
   `/home/soustredeni`, `/home/junior`, `/home/pikomat`…) — sdílené schránky
   čtené orgy přes **dovecot IMAP**. K tomu `/etc/postfix/aliases`
   (pikobrani → osobní adresy, webmaster → honza+vitas, root → honza).

Pozn.: bounce z 7/2026 ukázal **SPF fail** na outlook/msn — DNS SPF
neautorizuje odesílací server; maily na Microsoft domény se nedoručují.

## 3. Ekosystém pikusy (mimo hlavní server)

| Komponenta | Co | Kde běží | Auth | Stav |
|---|---|---|---|---|
| herna | realtime backend her | pikomat, systemd | tokeny | aktivní |
| pikviz | týmová kvízová hra | nad hernou | — | aktivní |
| prednasky | výukové HTML + kvízy → tep | `www/pub` | tep (friend/csrf) | aktivní |
| **afterleaf** | Overleaf-lite (sandbox LaTeX, CodeMirror, **Yjs kolaborace**, visual editor, PDF.js) | pikomat :3000 | vlastní OIDC (vyp.) | pokročilý prototyp; **poslední ~3 dny práce NEJSOU v gitu** (rename tex-server→afterleaf nezacommitován) |
| sklepress | tisk/sken server | **Raspberry Pi ve sklepě** (192.168.9.126) | **žádná** + veřejný dynDNS `…dedyn.io`; **tokeny (deSEC, NC) commitnuté v gitu** | používané |
| bleskarty | kartičky (5 předmětů) | `www/pub` | žádná (lokální profily) | rozpracovaný refaktor, velký necommitnutý diff |
| tep-foto | editor `{{foto}}` bloků wiki | `www/pub` | tep (`.csrf` + X-CSRF-Token) | nedokončené |
| aja | flotila dětských PC (snoopy, skubanek, jonatan, pluto) + Claude Code | LAN | ssh klíče | aktivní |
| hodiny | konzolové hodiny s režimem dne | Pi Zero (táž IP jako sklepress!) | žádná | aktivní |
| pikoraptor | hra + AI výukový materiál | `www/pub` | žádná | hotové |

Na serveru v `~/git` navíc: `marvin-klep` (**marvin = perl bot do klepu**,
`marvin.pl` + `pikoorg-cal.rb`, vlastní systemd; má i vlastní sklep sync
v `/home/marvin/sklep`), a **neidentifikované**: `bludiste.git`, `lagblast`,
`nextcloud-skyprint`, `pikomap`, `pikomapt` (viz otázky).

## 4. Autentizační mapa — tři světy

1. **Svět tepu (cíl):** tep Devise + role bitmask; Doorkeeper OAuth pro
   **klep** (přes „GitLab" endpoint trik) a **sklep** (social login, účty
   `tep-…@…`); session+`/csrf` pro statické klienty (přednášky, tep-foto);
   `friend` uuid pro anonymy.
2. **Vlastní ostrovy:** **preklep/Overleaf** (mongo účty — hlavní bolest),
   afterleaf (OIDC, zatím vypnuté), mailman, dovecot/IMAP (unix účty),
   htpasswd (`/provedouci`, `/tep-dev`, kartana).
3. **Bez autentizace:** statické hry/výuka (OK) a **sklepress** (NE-OK,
   je na veřejném dynDNS).

Klíčové pozorování: tep je **de facto IdP**, ale mluví třemi dialekty
(Doorkeeper OAuth2, GitLab-kompatibilní hack, csrf/session). Chybí mu
**standardní OIDC vrstva** — právě ta by sjednotila afterleaf (OIDC už umí!),
budoucí OxiCloud/Nextcloud (OIDC pluginy existují) i Mattermost (OIDC umí
v novějších verzích) bez dalších triků.

## 5. Nálezy a rizika (podle priority)

1. **Afterleaf není v gitu** — rename `tex-server`→`afterleaf` + Yjs
   kolaborace + visual editor žijí jen v pracovním stromu `~/git/pikusy`.
   Jedna chyba disku = ztráta. Commitnout hned.
2. **Sklepress: živé tokeny v gitu** (deSEC, Nextcloud app token) a služba
   bez auth vystavená přes dynDNS. Revokovat tokeny, dynDNS vypnout nebo dát
   za auth.
3. **SPF/DMARC** — maily z pikomatu na outlook/msn bounces. Oprava DNS.
4. **Overleaf docker ostrov**: vlastní účty, mongo + 12 node procesů + vlastní
   nginx na 8GB stroji; soubor `CRASH` v `/home/www/overleaf` naznačuje
   nedávný pád. Kandidát na náhradu afterleafem.
5. **Rudimenty k úklidu:** `/home/www/rails/{tep-pre (2014), redmine (2016),
   hello}`, staré sklepy (`sklep-old`, `nextsklep`, `nextcloud-18.0.3`,
   `owncloud-10.3.1`), mrtvé PG clustery 9.4/9.6/11/13 (datové adresáře),
   mailmantest* listy.
6. **Rok bez rebootu** — kernel se aktualizuje, ale nenabíhá; naplánovat
   restart okno (a tím ověřit, že všechno po rebootu nastartuje — je to
   zároveň test na „silný rychlý server".)
7. `/tep-dev` a kartana běží v `RackEnv development` na produkčním stroji
   (friendly error pages = únik informací; chrání je jen htpasswd).
8. Port `:33233` — neidentifikovaná služba s connection-token API.

## 6. Rozhodnutí a dovyšetřené položky (konzultace 2026-08-29)

| Položka | Verdikt / zjištění |
|---|---|
| mailman3 | **neprovozuje se** — služba failed, routing vypnutý; listy jen leží → služby disable, data archiv |
| `/kartana/souboj-bazin` | **zastavit** (vyžaduje root: smazat blok z apache vhostu) |
| `/saman` | nechat (Honzovy www) |
| `bludiste.git`, `lagblast` | nechat |
| `nextcloud-skyprint` | identifikováno: klon cizí NC aplikace **SkyPrint** (tisk z Nextcloudu přes CUPS) — před-pokus dnešního sklepressu; rudiment |
| `pikomap`, `pikomapt` | nechat |
| port `:33233` | **vyřešeno** (root, 8/2026): `code-f6cfa2ea24` = **VS Code Server** — pozůstatek něčího VS Code Remote-SSH/Tunnel připojení, ne služba Pikomatu. Vlastníka ukáže `ps -o user,lstart -p <pid>`; neaktivní instanci lze zabít (VS Code si ji příště nainstaluje znovu) |
| `epta` | **nemazat, nic se s ní neděje** — jen jsem si při skenu všiml aktivních IMAP procesů toho účtu; jde o běžně používanou schránku (stejný vzor jako tabor@/soustredeni@ = unix účet + dovecot). Žádná akce |
| `redmine` (2016) | smazat lze |
| `tep-pre` (2014) | testovací kopie tepu — smazat lze |
| `hello` (2013) | identifikováno: hračka na zkoušení Devise (routes s `sign_up => 'cmon_let_me_in'`) — smazat lze |
| staré sklepy | **POZOR na zrady**: `sklep-old` NENÍ kopie — je to **symlink na živou produkci** (druhé dveře k `/sklep`); `owncloud-10.3.1` už na disku neexistuje (alias visí do prázdna); `/home/www/sklep-data/data-18.0.3` je přes jméno **ŽIVÁ datová složka** produkce (symlink `data →` na ni, změny 7/2026) — **nedotýkat**. Skutečné staré kopie k archivaci: `nextsklep` (413 M, NC 18 app) a `nextcloud-18.0.3` (1,6 G app strom) |
| afterleaf běžící na :3000 | v pořádku — ladí se, zatím se nepoužívá |

### Připravené kroky (čekají na ruční spuštění / root)

Bez roota (vitas, skupina pikoweb stačí) — archivace starých app stromů:

```sh
mkdir -p /home/www/archiv
mv /home/www/html/nextsklep /home/www/archiv/
mv /home/www/html/nextcloud-18.0.3 /home/www/archiv/
rm /home/www/html/sklep-old        # symlink na živou produkci (duplikátní URL)
# obnova kdykoli: mv zpět, resp. ln -s nextcloud-26.0.13 /home/www/html/sklep-old
```

S rootem:

```sh
systemctl disable --now mailman3 mailman3-web    # mrtvé, jen error noise
# v /etc/apache2/sites-enabled/pikomat-ssl.conf smazat:
#   - blok /kartana/souboj-bazin (zastavit dle rozhodnutí)
#   - aliasy /sklep-old, /nextsklep, /nextcloud-18.0.3, /owncloud-10.3.1
#   - blok /mailman3
rm -rf /home/www/rails/{redmine,tep-pre,hello}   # schválené rudimenty
sudo ss -tlnp | grep -E "33233|42653"            # identifikace záhadných portů
```

## 7. Cílový stav a doporučená cesta

**Cíl: jeden silný server, jednotná autentizace, méně runtime světů.**
Dnešní runtime zoo: Ruby/Passenger + PHP/Nextcloud + Go/Mattermost +
node+mongo/docker (Overleaf) + Rust (herna, afterleaf) + Python/uwsgi
(mailman) + Perl (marvin). Směr, který dává smysl (a už fakticky běží):
**Rust pro nové služby, tep jako identity provider.**

### Krok 0 — hygiena (hned, levné)
Commit afterleafu; revokace sklepress tokenů; SPF fix; smazání rudimentů;
reboot okno; identifikace :33233.

### Krok 1 — tep jako pořádný IdP (základ všeho dalšího)
Přidat do tepu **OIDC** (gem `doorkeeper-openid_connect` nad stávajícím
Doorkeeperem — malý krok, žádná migrace účtů). Pak:
- afterleaf: jen zapnout `[auth] mode = oidc` proti tepu,
- Mattermost: přepnout z GitLab-hacku na OIDC (čistší upgrade path),
- budoucí sklep (OxiCloud/Nextcloud): OIDC login,
- mailman3 web umí OIDC přes django-allauth (volitelné).
Tím zmizí dialekty a **každá nová služba dostane login zadarmo**.

### Krok 2 — afterleaf místo preklepu (zbavit se dockeru + monga)
Dokončit: commit → OIDC na tep → ProxyPass `/afterleaf` v Apache → pilotní
projekt (ročenka?) → migrace projektů z Overleafu (export ZIPů — v Overleafu
CE jde per-projekt; SyncTeX/BibTeX omezení afterleafu ověřit na reálných
dokumentech) → vypnout `/preklep` (uvolní ~containery, mongo, node; na 8GB
stroji znatelné). Alias `preklep` může zůstat jako redirect.

### Krok 3 — sklep → OxiCloud (zbavit se PHP): pozor, zúžit očekávání
OxiCloud je mladý projekt — soubory ano, ale **neumí paritu s Nextcloudem**:
CalDAV **kalendáře** (dnes ve sklepu používané, well-known redirecty v Apache),
**Collabora** integraci, zralé **sync klienty** (tvůj desktop sync = oficiální
NC klient), share linky, App Passwords pro sklepress. Doporučení:
1. nejdřív **inventura, co ze sklepu doopravdy používáte** (soubory+sync,
   kalendáře, Collabora, sdílecí odkazy, app tokeny — každý bod = požadavek),
2. migrovat po vrstvách: soubory (105+ GB) do OxiCloud/jiného Rust úložiště,
   **kalendáře na samostatný CalDAV server** (např. `radicale` — Python, ale
   miniaturní; nebo `rustical` — CalDAV v Rustu), Collabora zvážit zda vůbec,
3. teprve pak vypnout PHP. Realistická mezistanice: Nextcloud držet jen na
   kalendáře, soubory už jinde.

### Krok 4 — tep v Rustu: strangler, ne přepis
Tep = Devise+role+OAuth, sosna, act, giwi wiki, kvízy, mailery — přepsat
najednou je multi-roční projekt. Reálná cesta, kterou už fakticky jedeš:
**nové funkce jako samostatné Rust služby za tep-OIDC** (herna, afterleaf,
další), z tepu postupně vyřezávat (nejdřív např. kvízy/friend API), jádro
(sosna/act/wiki) nechat v Rails, dokud slouží. Rozhodující předpoklad je
krok 1 — jakmile je identita venku z Rails session, dá se krájet.

## 8. Příloha: porty

| Port | Služba |
|---|---|
| 80/443 | Apache (vše veřejné) |
| 25/28, 143/993 | postfix, dovecot |
| 5432 / 5435 | PostgreSQL 15 (tep, klep…) / 17 |
| 8065 | Mattermost (klep) |
| 9980 | Collabora coolwsd |
| 20443, 2080/2081 | Overleaf (docker; TLS front + interní nginx) |
| 31415 | herna |
| 3000 | afterleaf (neexponovaný) |
| 33233 | ??? (connection-token služba) |
| 111 | rpcbind (NFS? — kandidát na vypnutí) |
