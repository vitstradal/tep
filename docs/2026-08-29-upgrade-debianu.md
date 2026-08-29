# Upgrade pikomatu: bookworm → trixie (runbook)

Datum: 2026-08-29. Předchází instalaci OxiCloudu (rozhodnuto: nejdřív OS).

## Skutečný stav (pozor na lživé indikátory)

- apt zdroje (deb822 v `/etc/apt/sources.list.d/`): **bookworm** main +
  updates + security + backports, sury PHP (bookworm), docker (trixie).
  → systém JE **Debian 12 bookworm**.
- `/etc/debian_version` říká „13.1" a os-release „trixie/sid" — **lže**:
  balík `base-files` se někdy povýšil mimo řadu. Nevěřit, řídit se apt.
- Kernel: běží `6.12.38+deb12` (bpo), nainstalován až `6.12.57+deb12`;
  **50 linux-image balíků** (léta neuklizeno). Uptime 382 dní = boot
  netestován.
- Čeká 16 upgradů (mj. ruby-rails 6.1 security — systémové Ruby balíky,
  které tep zřejmě nepoužívá, jede z rvm; kandidát na purge).
- PHP 8.4 ze sury (trixie má 8.4 nativně → sury po upgradu vyřadit).

## Fáze 0 — předpoklady (bez nich nezačínat)

1. **Zálohy** (dnes nezdokumentované!): minimálně
   - `pg_dumpall` z clusterů 15 i 17 mimo stroj,
   - sklep data (`/home/www/sklep-data/data-18.0.3` — 100+ GB, rsync jinam
     nebo aspoň na druhé pole),
   - `/etc`, `/opt/mattermost/config`, `/home/www/overleaf/config`,
     maily (`/home/*/Maildir` dle potřeby), crontaby.
2. **Reboot test na současném systému**: `apt upgrade` (16 balíků) →
   reboot do `6.12.57+deb12` → ověřit checklist služeb (níže). Teprve
   když stroj umí nabootovat bookworm, má smysl trixie.
3. Úklid PŘED upgradem (méně věcí k migraci):
   - mailman: `systemctl disable --now mailman3 mailman3-web`, pak
     `apt purge mailman3*` (data v `/var/lib/mailman3` archivovat),
   - staré kernely: `apt autoremove --purge` (nechá 2 poslední),
   - mrtvé PG clustery 9.4/9.6/11/13: `pg_dropcluster` po záloze,
   - rudimenty z TODO přehledu (redmine, tep-pre, hello…),
   - zvážit: `apt purge ruby-rails ruby-action* ruby-active*` — systémové
     Rails 6.1 balíky; tep jede z rvm (`/usr/local/rvm`), OVĚŘIT
     `PassengerRuby` u produkčního tepu, než se smažou.

## Fáze 1 — kontrolní checklist služeb (před i po)

```
curl -sk https://pikomat.mff.cuni.cz/ | grep -c Pikomat        # tep
curl -sk https://pikomat.mff.cuni.cz/csrf                      # tep api
curl -sk https://pikomat.mff.cuni.cz/sklep/status.php          # nextcloud
curl -sk https://pikomat.mff.cuni.cz/klep/api/v4/system/ping   # mattermost
curl -sk https://pikomat.mff.cuni.cz/preklep/ -o /dev/null -w "%{http_code}" # overleaf
curl -s  http://127.0.0.1:31415/ -o /dev/null                  # herna
curl -s  http://127.0.0.1:3000/  -o /dev/null                  # afterleaf
ss -tln | grep -E "25|143|993"                                 # mail
```

## Fáze 2 — dist-upgrade bookworm → trixie

1. V `/etc/apt/sources.list.d/`: `debian.sources` a
   `debian-backports.sources` přepnout Suites bookworm→trixie
   (security: `trixie-security`); **sury php.sources vypnout** (trixie má
   PHP 8.4); smazat `.bak` a starý `bookworm-backports.list` (duplikát).
2. `apt update && apt upgrade --without-new-pkgs` → `apt full-upgrade`
   (klasický dvoufázový postup dle release notes; číst prompty ke
   konfigurákům — zejména apache, postfix, dovecot, php-fpm).
3. Známé zádrhely tohoto stroje:
   - **PostgreSQL**: trixie nese PG 17 — bookworm PG 15 cluster zůstane
     běžet ze starých binárek jen do jejich odebrání; plán: po upgradu
     `pg_upgradecluster 15 main` (tep DB!) a starý dropnout. Cluster 17
     (:5435) se jen povýší na trixie build.
   - **PHP/Nextcloud**: přechod sury→trixie php-fpm; NC 30 na PHP 8.4 už
     běží, takže riziko malé; zkontrolovat `a2enconf php8.4-fpm`.
   - **Passenger/rvm**: tep jede z rvm ruby — apache `mod_passenger`
     z Debianu se povýší, ověřit kompatibilitu s rvm wrapperem
     (checklist tep hned po startu apache).
   - **Docker/Overleaf**: repo už trixie, containery se nemění; jen
     ověřit start po rebootu.
   - base-files anomálie se upgradem srovná sama.
4. `apt autoremove --purge`, reboot do trixie kernelu (6.12.x+deb13 /
   novější), checklist fáze 1.

## Fáze 3 — po upgradu

- `pg_upgradecluster 15 main` → tep na PG 17, dropnout 15 (a upravit
  případné odkazy na port — tep používá socket/5432, po upgradu cluster
  převezme 5432).
- Zapsat reboot režim (2× ročně) a záloh do crontabu/dokumentace.
- Teprve teď: **instalace OxiCloudu do /opt** (pilot dle světlých zítřků;
  binárka se builduje až na trixie glibc, tím odpadá kompatibilita).

## Poznámka k pořadí vs. OxiCloud

Build OxiCloudu je nezávislý (uživatelský home, localhost pilot), ale
rozhodnuto dělat OS první — binárka postavená na bookworm glibc by po
upgradu fungovala, opačně to neplatí, a hlavně: jeden velký zásah po
druhém, ne dva najednou.
