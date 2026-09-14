# Světlé zítřky — cílová architektura pikomatího serveru

Datum: 2026-08-29. Navazuje na `2026-08-29-prehled-pikomatiho-serveru.md`
(současný stav + úklid). Zachycuje rozhodnutí z konzultace:

- **Identita: tep Doorkeeper OAuth2, tak jak je** — žádná OIDC vrstva se
  nestaví; každá služba se integruje proti Doorkeeperu (authorize/token +
  `/oauth/me` přes CredentialsController). Klep i sklep to tak už dělají.
- **Sklep: OxiCloud (soubory) + rustical (CalDAV kalendáře)** — zbavit se
  PHP úplně.
- **Železo: přestavba na místě** — žádný nový stroj; současný server se
  modernizuje za provozu (a uvolní se prostředky vypnutím docker ostrova).
- **První viditelný výsledek: afterleaf nahradí preklep (Overleaf).**

## 1. Zásady

1. **Rust pro služby** — nové věci jako malé samostatné axum služby na
   localhost portech za Apache proxy (vzor: herna, afterleaf, sklepress).
2. **Jedna identita = tep OAuth2.** Neexistuje služba s vlastními účty.
   Anonymové = friend uuid (kvízový svět).
3. **Méně runtime světů.** Cíl: Ruby (tep) + Rust (služby) + Go (Mattermost)
   + Python (mailman ne — ruší se). Odchází: PHP (Nextcloud), node+mongo+
   docker (Overleaf), Perl časem (marvin bot → přepsat/nechat dožít).
4. **Rails tep se přepisuje do Rustu stranglerem** (s pomocí Claude) —
   doména po doméně nad stejnou databází, každý krok nasaditelný a
   vratný; cílem je časem úplný odchod Rails (viz etapa 3).
5. Data mají jasné místo: PG 15→17 (jeden cluster), soubory sklepu na
   `/home` RAID, zálohy mimo stroj (dnes nejasné — součást etapy 4).

## 2. Cílová mapa (dnes → zítra)

| Oblast | Dnes | Zítra |
|---|---|---|
| identita | tep Devise + Doorkeeper | **beze změny** (jen víc klientů) |
| web/wiki/sosna/act | tep (Rails) | tep, postupný strangler do Rust služeb |
| kvízy/friend | tep | kandidát č. 1 na vyříznutí do Rustu |
| LaTeX | Overleaf CE (docker, mongo, vlastní účty) | **afterleaf** (Rust, tep OAuth2, `/afterleaf`; `/preklep` = redirect) |
| soubory | Nextcloud 30 (PHP) `/sklep` | **OxiCloud** (Rust) `/sklep` |
| kalendáře | Nextcloud CalDAV | **rustical** (Rust CalDAV) `/caldav`, well-known redirecty |
| dokumenty online | Collabora (coolwsd) | **ruší se bez náhrady** (bez NC nemá WOPI hosta; ověřit, že orgům stačí stažení/nahrání souboru — jinak přehodnotit) |
| chat | Mattermost (GitLab-trik na tep) | beze změny |
| mail | postfix + dovecot (unix schránky), SPF rozbité | beze změny + opravit SPF/DKIM; mailman pryč |
| hry/výuka | herna, pub statika | beze změny |
| tisk | sklepress (Pi, bez auth) | sklepress + aspoň token/auth, přepojit z NC WebDAV na OxiCloud |

## 3. Etapa 1 — afterleaf nahradí preklep

Stav: afterleaf běží na :3000 (ladí se), auth vypnutá, poslední práce
**nezacommitovaná**; má hotový OIDC modul, ale tep OIDC neumí a stavět se
nebude → afterleaf se musí naučit **plain OAuth2 proti Doorkeeperu**.

1. Commit afterleafu do pikusy (viz TODO přehledu).
2. **Auth modul: OAuth2 code flow proti tepu** — `/oauth/authorize`,
   `/oauth/token`, identita z `GET /oauth/me` (CredentialsController).
   Mapování: tep user → afterleaf user; role org → afterleaf admin.
   (Stejný vzor, jakým jede Mattermost, jen bez GitLab formátu — `/me`
   vrací tep JSON; případně v tepu přidat GitLab-kompatibilní endpoint,
   pokud by se nechtělo sahat do afterleafu — rozhodnout při implementaci.)
3. V tepu: založit OAuth aplikaci (Doorkeeper) pro afterleaf.
4. Apache: `ProxyPass /afterleaf http://127.0.0.1:3000/` (root).
5. Pilot: 1–2 reálné dokumenty (ročenka, leták) — ověří sandbox limity
   (BibTeX/Biber zatím není! SyncTeX není — ověřit, že to orgům nevadí).
6. Migrace: z Overleafu per-projekt ZIP export → import do afterleafu
   (příp. skript přes overleaf mongo, až podle počtu projektů).
7. Přepnutí: `/preklep` → redirect na `/afterleaf`; docker stack stop.
   **Zisk: ~containery+mongo+12×node na 8GB stroji + konec vlastních účtů.**
8. Po měsíci klidu: `docker`/`containerd` z počítače pryč (pokud nic
   jiného nepoužívá), smazat `/home/www/overleaf` (po záloze dat).

Hotovo = orgové píšou ročenku v afterleafu přihlášení tep účtem a docker
na stroji neběží.

## 4. Etapa 2 — sklep v Rustu (OxiCloud + rustical)

Vědomě zvolená odvážnější cesta; klíč je **pilot vedle produkce**, žádný
big-bang. Známé mezery OxiCloudu: mladý projekt, nemá vlastní desktop sync
klient (sync = WebDAV: rclone/klienti třetích stran), nemá Collaboru,
share-linky/ACL ověřit na místě. Proto:

1. **Inventura použití dnešního sklepu** (před čímkoli): kdo používá
   desktop sync (min. vitas — 145 GB, marvin bot, sklepress token), kdo
   kalendáře (pikoorg-cal), kdo share-linky, kdo Collaboru. Každé použití
   = požadavek s vlastníkem.
2. Pilot: OxiCloud na localhost portu, Apache `/oxisklep`, auth přes tep
   OAuth2 (pokud OxiCloud neumí — fronta přes `mod_auth_openidc` nepůjde
   bez OIDC; fallback: vlastní tenký Rust proxy s tep OAuth2, nebo
   OxiCloud upravit — **ověřit v pilotu jako první věc**).
3. Kalendáře (revize 2026-09-14): rustical NEPOTŘEBA — OxiCloud má
   vlastní plnohodnotný CalDAV server (`/caldav`, události v PG; ověřeno
   ve zdrojácích: MKCALENDAR, calendar-query/multiget REPORT, PROPFIND,
   PUT). OxiCloud ale nemá kalendářové web UI (SPA jen soubory/foto/
   hudba). Proto: **klikací kalendář postavit v tepu** (FullCalendar.js,
   org auth) — tep čte/zapisuje na OxiCloud CalDAV server-side jedním
   service app-heslem; rozšířit stávající `lib/cal_dav_report.rb` o zápis
   (PUT VEVENT, gem `icalendar` už je). Kanonický store = OxiCloud, takže
   telefony (DAVx5), Thunderbird, wiki `{{calendar}}` i `pikoorg-cal.rb`
   (marvin) čtou tentýž kalendář — jen přesměrovat URL z NC na OxiCloud.
   Blokuje to běžící OxiCloud pilot (nejdřív založit kalendář+service účet).
4. Data: 105+ GB kopírovat rsyncem po skupinách (Tabor, Soustredeni, …),
   read-only okno až na finální přepnutí `/sklep`.
5. Nextcloud po přepnutí zmrazit read-only, po půl roce archiv (app strom
   + `data-18.0.3` → archiv, POZOR je to živá složka do poslední chvíle).
6. Collabora (`coolwsd`) vypnout, pokud inventura nenajde tvrdého uživatele.

Hotovo = `/sklep` servíruje Rust, PHP na stroji neběží, kalendáře jedou
z rusticalu, sklepress i marvin přepojeni.

## 5. Etapa 3 — přepis tepu do Rustu (strangler, s Claudem)

**Záměr: tep se postupně celý přeprogramuje do Rustu s pomocí Claude
(AI-assisted rewrite).** Pořád stranglerem — doména po doméně, každý krok
nasaditelný a smazatelný — ale s AI asistencí je realistický i konec cesty
(kompletní odchod Rails), ne jen okusování okrajů. Vzor už existuje:
afterleaf (Rust/axum + spec + plány + testy) vznikl přesně takhle.

Metodika na každou doménu:

1. **Spec first** — z chování Rails kódu a testů se sepíše spec (Claude
   umí vytěžit controller+model+view do dokumentu; člověk škrtá rudimenty
   — přepis je zároveň příležitost NEpřenést 15 let sedimentu).
2. **Testy jako kontrakt** — stávající minitest suite tepu (od 7/2026
   zelená a rostoucí) se doplní tak, aby popisovala chování domény; Rust
   služba musí projít ekvivalentními testy (HTTP kontrakt).
3. Rust služba (axum + sqlx nad **stejnou PG databází** — data se
   nestěhují, schéma zůstává, což drží přepis vratný).
4. **Stínový provoz** → Apache přepne cestu → Rails kód domény se smaže.

Pořadí podle oddělitelnosti:

1. **kvízy + friend API** — už dnes čisté JSON API s vlastními tabulkami,
   minimální vazby na zbytek. První Rust výřez; ideální pilot metodiky.
2. **giwi wiki** — git-backed, dobře ohraničené; Rust služba s rendererem,
   auth přes tep role.
3. **act (akce)** — střední; hodně formulářů (tady se poprvé řeší
   server-rendered HTML v Rustu — askama/maud, nebo SPA?).
4. **sosna (řešitelé, řešení, výsledkovky)** — jádro s maily a PDF
   (labels/prawn!) — největší kus, jde poslední.
5. **identita** (Devise + Doorkeeper) — úplně nakonec: Rust auth služba
   převezme users tabulku a OAuth2 endpointy se zachováním kontraktu,
   aby klep/sklep/afterleaf nic nepoznaly. Tím Rails končí.

Praktická poznámka k práci s Claudem: každá doména = vlastní spec +
implementační plán v `docs/` (jako u kvízů a afterleafu), commity po
malých krocích, testy před implementací. Rychlost nechť určuje kapacita
na review — ne kapacita generování.

## 6. Etapa 4 — stroj (přestavba na místě)

1. Úklid dle TODO přehledu (rudimenty, mailman, mrtvé PG clustery).
2. **Debian: ze sid/trixie na stable track** + pravidelný reboot režim
   (např. 2× ročně, o prázdninách akcí); první reboot co nejdřív — 380+
   dní uptime znamená netestovaný boot.
3. PG: konsolidovat na 17 (tep dnes na 15) — `pg_upgrade`, jeden cluster.
4. **Zálohy**: dnes nezdokumentované → zavést (restic/borg mimo stroj;
   PG dumpy, sklep data, /etc, maily). Bez toho žádná další migrace.
5. Monitoring lehký (uptime + disk + služby; třeba jen systemd
   OnFailure → mail, žádný Prometheus cirkus).
6. RAM: po vypnutí dockeru/monga/PHP se 8 GB uleví; kdyby ne, teprve pak
   řešit železo.

## 7. Co se vědomě NEřeší

- OIDC vrstva (rozhodnuto: Doorkeeper stačí; každá nová služba si napíše
  OAuth2 klienta — přijatá cena za jednoduchost).
- Nový stroj / VM / kontejnerizace — přestavba na místě.
- Mail stack (postfix/dovecot/IMAP schránky) — funguje, jen SPF/DKIM fix.
- Mattermost — zůstává (Go, jeden binár, auth přes tep už má).
- marvin bot (Perl) — dožívá, přepis až bude důvod (např. při přepojování
  kalendářů v etapě 2 se ověří, že mu rustical stačí).

## 8. Pořadí a milníky

```
Ú  úklid (TODO z přehledu) ──────────────► kdykoli po kouskách
E1 afterleaf → preklep      ─────────────► první viditelný výsledek
E4a zálohy + reboot režim   ─────────────► podmínka pro E2
E2 sklep → OxiCloud+rustical (pilot → data → přepnutí)
E4b stable track, PG17, monitoring
E3 strangler tepu (kvízy → wiki → act → sosna?)
```

Každá etapa končí smazáním něčeho starého — to je metrika světlých zítřků:
**počet běžících runtime na stroji klesá** (dnes 7: ruby, php, go, node,
mongo/docker, python-uwsgi, perl → cíl 3: ruby, rust, go).
