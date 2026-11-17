# Přihlášení pomocí jiného zařízení — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nové zařízení ukáže 4 ikony, uživatel je zadá na už přihlášeném zařízení, potvrdí, a nové zařízení se přihlásí (bez remember me).

**Architecture:** Záznam `DeviceLogin` v DB se stavovým automatem (`pending → approved → done`, `cancelled`), přechody atomickým `update_all … WHERE state = …`. Nové zařízení se identifikuje náhodnou cookie (v DB SHA-256) a dotazuje se JSON endpointu po 2 s. Jeden controller `DeviceLoginController` pro obě strany, jQuery v `public/javascripts/tep.js`.

**Tech Stack:** Rails 7.2, Devise (`sign_in`/`sign_out`), CanCanCan (`authorize_resource class: false`), jQuery, minitest `ActionController::TestCase` + `Devise::Test::ControllerHelpers`, sqlite v testech.

**Spec:** `docs/superpowers/specs/2026-11-17-prihlaseni-v-mobilu-design.md`

## Global Constraints

- Testy: `export PATH=$HOME/.rvm/gems/ruby-3.2.1/bin:$HOME/.rvm/gems/ruby-3.2.1@global/bin:$HOME/.rvm/rubies/ruby-3.2.1/bin:$PATH GEM_HOME=$HOME/.rvm/gems/ruby-3.2.1 GEM_PATH=$HOME/.rvm/gems/ruby-3.2.1:$HOME/.rvm/gems/ruby-3.2.1@global; RAILS_ENV=test bundle exec rails test <soubor>`.
- Testovací DB se staví ze `db/schema.rb` (migrace od nuly nejdou) → každou migraci promítnout ručně i do `db/schema.rb` a zvýšit `version:`.
- Migrace se jmenují sekvenčně: další je `041_…`, `ActiveRecord::Migration[7.2]`.
- Komentáře v kódu: nejvýš jeden řádek, popisují současný stav. Commity bez Co-Authored-By, na `master`.
- Texty UI česky. Názvy: přihlášená strana „Přihlásit na jiném zařízení“, nepřihlášená „Přihlásit pomocí jiného zařízení“.
- Pool ikon (pořadí = index 0–23): 🍎 jablko, 🍌 banán, 🍇 hrozny, 🍉 meloun, 🥕 mrkev, 🍕 pizza, 🍄 houba, 🌵 kaktus, 🌻 slunečnice, 🌙 měsíc, ⭐ hvězda, 🔥 oheň, 🐘 slon, 🐟 ryba, 🐢 želva, 🐝 včela, 🐧 tučňák, 🦋 motýl, 🚗 auto, 🚲 kolo, 🚀 raketa, ⚽ míč, 🎸 kytara, 🔑 klíč.
- Hodnoty: kód 4 ikony, opakování povoleno, platnost 5 min; Ano do 2 min po schválení; strop 500 platných `pending`; vytváření 30 / hod na IP (IPv6 po /64); neúspěšná zadání 5 / min a 20 / hod na uživatele; max 10 pokusů o unikátní kód; záznamy starší 1 dne se mažou při vytvoření nového.
- Bez remember me pro všechny. Mail vlastníkovi po každém přihlášení.
- Všechny zápisové akce POST; controller `protect_from_forgery with: :exception`.
- Schvaluje `real_user` (ne `current_user` — může být kopie „Jak to vidí“).
- Nepoužívat nové gemy.

## Review Focus

1. Nové zařízení je už přihlášené za někoho jiného → po Ano je přihlášené za nového uživatele (nejdřív `sign_out`), ne za oba ani za starého.
2. Uživatel zadá kód, který mezitím vypršel nebo ho zrušilo nové zařízení → „Kód neplatí nebo vypršel“, ne výjimka 500; Potvrdit na už nepending záznam → `ok: false`.
3. Org v režimu „Jak to vidí: anon“ (`current_user` nil, `real_user` existuje) otevře klávesnici → funguje a schvaluje `real_user`.
4. Reload stránky nového zařízení během čekání → nový kód (starý záznam téhož zařízení se zruší), žádná výjimka kvůli staré cookie.
5. Zamčený / nepotvrzený účet → nové zařízení dostane hlášku, Devise nevyhodí `throw :warden` do JSON akce, záznam neskončí v `done`.

---

## File Structure

- `app/controllers/application_controller.rb` — `safe_return_path`, oprava `after_sign_in_path_for`.
- `db/migrate/041_create_device_logins.rb`, `db/schema.rb` — tabulky `device_logins`, `device_login_attempts`.
- `app/models/device_login.rb` — pool ikon, kódy, limity, atomické přechody, popis zařízení.
- `app/models/device_login_attempt.rb` — limit neúspěšných zadání.
- `app/controllers/device_login_controller.rb` — obě strany.
- `app/views/device_login/novy.html.erb`, `app/views/device_login/klavesnice.html.erb`.
- `app/mailers/tep/mailer.rb`, `app/views/tep/mailer/device_login_email.html.erb`.
- `config/routes.rb`, `app/models/ability.rb`.
- `app/views/layouts/application.html.erb` (dropdown pro všechny), `app/views/devise/sessions/new.html.erb` (odkaz).
- `public/javascripts/tep.js` — `init_device_login_new`, `init_device_login_keyboard`.
- Testy: `test/functional/safe_return_path_test.rb`, `test/models/device_login_test.rb`, `test/functional/device_login_controller_test.rb`.

---

### Task 1: Bezpečný návrat po přihlášení

**Files:**
- Modify: `app/controllers/application_controller.rb:25-30`
- Test: `test/functional/safe_return_path_test.rb`

**Interfaces:**
- Produces: `ApplicationController#safe_return_path(path) -> String | nil` (protected) — vrátí `path`, jen když je to String začínající `/` a ne `//` ani `/\`, jinak `nil`.

- [ ] **Step 1: Write the failing tests** — `ActionController::TestCase` nad `Devise::SessionsController` (`@request.env['devise.mapping'] = Devise.mappings[:user]`), uživatel vytvořený jako v `test/functional/adventomat_controller_test.rb` (`skip_confirmation!`):
  - `test 'next with local path redirects there'`: `post :create, params: {user: {email:, password:}, next: '/sosna'}` → `assert_redirected_to '/sosna'`.
  - `test 'next with external url is ignored'`: `next: 'https://evil.example/'` → redirect není na `evil.example` (`refute_match /evil/, response.location`).
  - `test 'protocol-relative next is ignored'`: `next: '//evil.example/x'` → totéž.
  - `test 'stored location is used'`: `session['user_return_to'] = '/oauth/authorize?client_id=x'` před `post :create` bez `next` → `assert_redirected_to '/oauth/authorize?client_id=x'`.
- [ ] **Step 2: Run, expect FAIL** (externí next dnes projde, stored location se ignoruje).
- [ ] **Step 3: Implement** `safe_return_path` a `after_sign_in_path_for(user)` = `safe_return_path(params[:next]) || safe_return_path(stored_location_for(user)) || url_for_root(user)`.
- [ ] **Step 4: Run the file + whole suite, expect PASS.**
- [ ] **Step 5: Commit** `přihlášení: návrat jen na lokální cestu, použije i uloženou adresu (OIDC)`.

### Task 2: Model a migrace

**Files:**
- Create: `db/migrate/041_create_device_logins.rb`, `app/models/device_login.rb`, `app/models/device_login_attempt.rb`
- Modify: `db/schema.rb` (obě tabulky, `version: 41`)
- Test: `test/models/device_login_test.rb`

Tabulky:
- `device_logins`: `code` string not null, `state` string not null default `'pending'`, `user_id` integer, `device_digest` string not null, `user_agent` text, `ip` string, `ip_bucket` string, `return_to` text, `approved_at` timestamptz, `expires_at` timestamptz not null, timestamps; indexy `[:code, :state]`, `:device_digest`, `[:ip_bucket, :created_at]`.
- `device_login_attempts`: `user_id` integer not null, `ok` boolean not null default false, `created_at` timestamptz not null; index `[:user_id, :created_at]`.

**Interfaces:**
- Produces (`DeviceLogin`):
  - `ICONS` — pole 24 dvojic `[emoji, název]` v pořadí z Global Constraints.
  - `TTL = 5.minutes`, `APPROVE_TTL = 2.minutes`, `MAX_PENDING = 500`, `IP_LIMIT = 30` (za hodinu).
  - `class Busy < StandardError`.
  - `self.digest(token) -> String` (SHA-256 hex).
  - `self.ip_bucket(ip) -> String` (IPv4 celá, IPv6 prvních 64 bitů, např. `2001:db8:1:2::/64`).
  - `self.create_for!(token:, user_agent:, ip:, return_to:) -> DeviceLogin` — smaže záznamy starší 1 dne, zruší (`cancelled`) předchozí `pending` téhož `device_digest`, raise `Busy` při ≥ `MAX_PENDING` platných pending nebo ≥ `IP_LIMIT` záznamech z `ip_bucket` za hodinu; kód = 4 náhodné indexy (`SecureRandom.random_number(24)`) jako `"3-17-0-22"`, unikátní mezi platnými pending, max 10 pokusů, pak `Busy`.
  - `self.find_pending(indices) -> DeviceLogin | nil` — platný (`expires_at > now`) pending s tímto kódem; `indices` pole 4 Integerů 0–23, jinak nil.
  - `self.for_device(token) -> DeviceLogin | nil` — poslední záznam s `device_digest`.
  - `#icons -> [[emoji, název] × 4]`.
  - `#approve!(user) -> Boolean` — atomicky `pending → approved`, `user_id`, `approved_at = now`, jen pokud `expires_at > now`.
  - `#finish!(token) -> Boolean` — atomicky `approved → done`, jen pokud digest sedí a `approved_at > now - APPROVE_TTL`.
  - `#cancel!(from: %w[pending approved]) -> Boolean` — atomicky do `cancelled`.
  - `#device_label -> String` — z User-Agent: systém (Android / iPhone / iPad / Windows / Mac / Linux / „neznámý systém“) · prohlížeč (Edge / Firefox / Chrome / Safari / „neznámý prohlížeč“; Edge před Chrome, Chrome před Safari).
  - `#same_network?(ip) -> Boolean` — `ip_bucket(ip) == ip_bucket`.
  - `#expires_in -> Integer` sekund (≥ 0).
- Produces (`DeviceLoginAttempt`): `PER_MIN = 5`, `PER_HOUR = 20`; `self.begin!(user) -> DeviceLoginAttempt | nil` — nejdřív vloží řádek `ok: false`, pak spočítá neúspěchy (včetně nového) za minutu / hodinu; nad limitem vrátí nil (řádek zůstane); `#succeed!` nastaví `ok: true`.

- [ ] **Step 1: Write failing model tests** (`ActiveSupport::TestCase`, `travel_to` pro čas):
  - `ICONS.size == 24`, `ICONS[6] == ['🍄', 'houba']`.
  - `create_for!` → `state 'pending'`, `code =~ /\A\d+-\d+-\d+-\d+\z/`, všechny indexy 0–23, `expires_at ≈ now + 5 min`, `device_digest == digest(token)`.
  - kolize: stubnout `SecureRandom.random_number` tak, aby 1. kód kolidoval s existujícím pending → druhý záznam má jiný kód; když koliduje vždy → `Busy`.
  - strop: 500 platných pending (vložit `insert_all`) → `Busy`; vypršelé se nepočítají.
  - IP: 30 záznamů z `1.2.3.4` za hodinu → 31. `Busy`; `2001:db8:1:2::5` a `2001:db8:1:2::9` sdílí bucket, `2001:db8:1:3::5` ne.
  - nový `create_for!` téhož tokenu zruší předchozí pending.
  - `find_pending([…])` najde; po `expires_at` nil; špatné vstupy (`[1,2,3]`, `[1,2,3,24]`, `['a',1,2,3]`) nil.
  - `approve!` true jednou, podruhé false; po vypršení false.
  - `finish!(token)` po approve true; se špatným tokenem false; po 2 min 1 s false; podruhé false.
  - `device_label`: Android Chrome UA → `'Android · Chrome'`; iPhone Safari → `'iPhone · Safari'`; Windows Edge (`Edg/`) → `'Windows · Edge'`; prázdný → `'neznámý systém · neznámý prohlížeč'`.
  - `DeviceLoginAttempt.begin!`: 5 neúspěchů za minutu → 6. vrátí nil; po minutě znovu jde; 20 za hodinu → 21. nil; úspěšné (`succeed!`) se nepočítají.
- [ ] **Step 2: Run, expect FAIL** (třídy neexistují).
- [ ] **Step 3: Migration + schema.rb + models.**
- [ ] **Step 4: Run model tests + whole suite, PASS.**
- [ ] **Step 5: Commit** `přihlášení jiným zařízením: model DeviceLogin s kódem ze 4 ikon, limity a atomickými přechody`.

### Task 3: Strana nového zařízení (stránka, vytvoření, stav, Ano/Ne, mail)

**Files:**
- Create: `app/controllers/device_login_controller.rb`, `app/views/device_login/novy.html.erb`, `app/views/tep/mailer/device_login_email.html.erb`
- Modify: `config/routes.rb`, `app/models/ability.rb`, `app/mailers/tep/mailer.rb`, `app/views/devise/sessions/new.html.erb`
- Test: `test/functional/device_login_controller_test.rb`

**Routes** (`as:` v závorce):
- `GET  /prihlasit-zarizenim` → `device_login#novy` (`device_login_novy`)
- `POST /prihlasit-zarizenim` → `#vytvor` (`device_login_vytvor`)
- `GET  /prihlasit-zarizenim/stav` → `#stav` (`device_login_stav`)
- `POST /prihlasit-zarizenim/ano` → `#ano` (`device_login_ano`)
- `POST /prihlasit-zarizenim/ne` → `#ne` (`device_login_ne`)

**Ability:** `can %i[novy vytvor stav ano ne], :device_login` pro všechny.

**Interfaces:**
- Consumes: `DeviceLogin.create_for!`, `.for_device`, `#icons`, `#finish!`, `#cancel!`, `#expires_in`, `#device_label`, `#return_to`, `DeviceLogin::Busy`; `safe_return_path` (Task 1).
- Produces:
  - `DeviceLoginController::COOKIE` = `'__Host-tep_dl'` v produkci, jinak `'tep_dl'`; cookie `httponly: true, same_site: :lax, secure: Rails.env.production?, path: '/'`, hodnota `SecureRandom.urlsafe_base64(32)`, vždy nová při `vytvor`.
  - `novy`: uloží do `session[:device_login_return_to]` `safe_return_path(params[:next]) || safe_return_path(stored_location_for(:user))`; view má `<div id="device-login-new">` s daty pro JS (URL endpointů).
  - `vytvor` JSON: `{icons: [[emoji, název]×4], expires_in:}`; při `Busy` status 429 `{error: 'Teď to nejde, zkus to za chvíli.'}`.
  - `stav` JSON (`Cache-Control: no-store`): `{state:, expires_in:}` a jen při `approved` navíc `name:` (`user.full_name` nebo e-mail, když je prázdné); bez cookie / záznamu `{state: 'none'}`.
  - `ano` JSON: `{ok: true, url:}` / `{ok: false, error:}`. Pořadí: najít podle cookie; uživatel `active_for_authentication?` jinak `{ok:false, error: <user.inactive_message přeložený>}` + `cancel!`; `finish!` (false → `{ok:false, error:'Potvrzení vypršelo, začni znovu.'}`); `sign_out(:user)` pokud přihlášen; `sign_in(:user, user)` (bez remember); mail `Tep::Mailer.device_login_email(user, label, Time.current).deliver_later`; `url` = `record.return_to` (a `add_success 'Jsi přihlášený, pokračuješ tam, kam jsi mířil.'`) nebo `url_for_root(user)` (a `add_success 'Jsi přihlášený.'`); smazat cookie.
  - `ne`: `cancel!(from: %w[approved])`, `{ok: true}`.
  - `Tep::Mailer#device_login_email(user, device_label, at)` — `mail(to: user.email, from: 'tep@pikomat.mff.cuni.cz', subject: 'PIKOMAT: přihlášení na jiném zařízení')`; text: „Přihlásil ses na <device_label> <at d. m. H:MM>. Pokud jsi to nebyl ty, změň si heslo.“
- `vytvor` ukládá `return_to` ze `session.delete(:device_login_return_to)`.
- Odkaz pod formulářem v `devise/sessions/new.html.erb`: „Přihlásit pomocí jiného zařízení“ na `device_login_novy_path(next: params[:next])`.

- [ ] **Step 1: Write failing functional tests** (`ActionController::TestCase`, `Devise::Test::ControllerHelpers`, `include ActiveJob::TestHelper`):
  - `novy` vrací 200 anonymně.
  - `vytvor` → 200, JSON `icons.size == 4`, cookie `tep_dl` nastavená, záznam pending s `device_digest == DeviceLogin.digest(cookie)`.
  - `vytvor` při `Busy` (stub `DeviceLogin.create_for!` raise) → 429.
  - `stav` bez cookie → `state 'none'`; pending → `state 'pending'`, žádné `name`; po `approve!` → `name` přítomné; hlavička `Cache-Control` obsahuje `no-store`.
  - `ano` po `approve!(u)` → `ok`, `@controller.current_user == u`, záznam `done`, `assert_enqueued_emails 1`, `cookies[:remember_user_token]` nil.
  - `ano` přihlášený za jiného (`sign_in other`) → po Ano `current_user == u`.
  - `ano` s jinou cookie → `ok false`, nepřihlášen.
  - `ano` po 2 min 1 s od approve → `ok false`.
  - `ano` zamčeného uživatele (`u.lock_access!`) → `ok false`, záznam `cancelled`, nepřihlášen.
  - `ano` s `return_to` → `url == return_to`; bez → root.
  - `novy?next=//evil` → `session[:device_login_return_to]` nil.
  - `ne` po approve → záznam `cancelled`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement routes, ability, controller, view, mailer, login link.** View `novy`: nadpis „Přihlásit pomocí jiného zařízení“, prázdný kontejner na ikony, text „Zadej tyto 4 obrázky na zařízení, kde jsi přihlášený, v menu „Přihlásit na jiném zařízení“.“, odpočet, tlačítko „Nový kód“; `<noscript>` hláška, že je potřeba JavaScript.
- [ ] **Step 4: Run tests + suite, PASS.**
- [ ] **Step 5: Commit** `přihlášení jiným zařízením: strana nového zařízení (kód, stav, Ano/Ne, mail)`.

### Task 4: Přihlášená strana (klávesnice, kód, potvrzení) a menu

**Files:**
- Modify: `app/controllers/device_login_controller.rb`, `config/routes.rb`, `app/models/ability.rb`, `app/views/layouts/application.html.erb:97-114`
- Create: `app/views/device_login/klavesnice.html.erb`
- Test: `test/functional/device_login_controller_test.rb`

**Routes:**
- `GET  /prihlasit-zarizeni` → `#klavesnice` (`device_login_klavesnice`)
- `POST /prihlasit-zarizeni/kod` → `#kod` (`device_login_kod`)
- `POST /prihlasit-zarizeni/potvrdit` → `#potvrdit` (`device_login_potvrdit`)
- `POST /prihlasit-zarizeni/zrusit` → `#zrusit` (`device_login_zrusit`)

**Ability:** `can %i[klavesnice kod potvrdit zrusit], :device_login` pro přihlášené. Pozor na „Jak to vidí: anon“ (`current_user` nil): akce na této straně navíc vyžadují `real_user` (`before_action`, jinak redirect na přihlášení) a autorizaci proti `Ability.new(real_user)`.

**Interfaces:**
- Consumes: `DeviceLogin.find_pending`, `#approve!`, `#cancel!`, `#device_label`, `#same_network?`, `#created_at`; `DeviceLoginAttempt.begin!`, `#succeed!`.
- Produces:
  - `klavesnice` view: `<div id="device-login-keyboard">` s 24 tlačítky (`data-i` = index, emoji + název, mřížka 4×6), 4 pole, „Smazat“; text „Na novém zařízení dej na přihlašovací stránce „Přihlásit pomocí jiného zařízení“ a sem zadej 4 obrázky, které se ti tam ukážou.“
  - `kod` (param `code[]` = 4 indexy) JSON: `begin!` nil → 429 `{ok:false, error:'Moc pokusů, zkus to za chvíli.'}`; nenalezen → `{ok:false, error:'Kód neplatí nebo vypršel.'}`; nalezen → `succeed!`, `{ok:true, id:, device: label, same_network: bool, age: sekund}`.
  - `potvrdit` (param `id`) JSON: `DeviceLogin.find_by(id:)&.approve!(real_user)` → `{ok: bool}`.
  - `zrusit` (param `id`): `cancel!(from: %w[pending])` → `{ok: true}`.
- Layout: místo dvou větví (dropdown jen pro `view_as_allowed?` / prostý štítek) jeden dropdown pro každého přihlášeného s `real_user.email` (`hidden-xs`): položka „Přihlásit na jiném zařízení“ (`device_login_klavesnice_path`, ikona `fa-mobile`) a pod ní přepínač „Jak to vidí“ jen pro `view_as_allowed?`.

- [ ] **Step 1: Write failing tests:**
  - `klavesnice` anonymně → redirect na přihlášení; přihlášený → 200 a 24 tlačítek (`assert_select '#device-login-keyboard [data-i]', 24`).
  - `kod` správný → `ok`, `device`, `same_network true` (stejná `@request.remote_addr`); jiná IP → `false`.
  - `kod` špatný → `ok false`; 6. špatný za minutu → 429.
  - `kod` vypršelý → `ok false`.
  - `potvrdit` → záznam `approved`, `user_id == u.id`; podruhé `ok false`.
  - `potvrdit` v „Jak to vidí“: morg s `session[:view_as_switch] = true, session[:view_as] = 'anon'` → `approved` s `user_id == morg.id`.
  - `zrusit` → `cancelled`.
  - layout: přihlášený obyčejný uživatel má v hlavičce odkaz na `device_login_klavesnice_path`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests + suite, PASS** (včetně `test/functional/view_as_test.rb` kvůli úpravě layoutu).
- [ ] **Step 5: Commit** `přihlášení jiným zařízením: klávesnice ikon, potvrzení, položka v menu pod uživatelem`.

### Task 5: JavaScript obou stran

**Files:**
- Modify: `public/javascripts/tep.js` (vedle `init_adventomat_app`, navázání v document ready u `$('#adventomat-app')…`), `app/views/layouts/application.html.erb` (`tep.js?v=` +1)

**Interfaces:**
- Consumes: endpointy z Task 3 a 4; CSRF token z `<meta name="csrf-token">` (stejně jako `friend_csrf()`).
- Produces: `init_device_login_new($el)`, `init_device_login_keyboard($el)`.

Chování:
- `init_device_login_new`: POST `vytvor` → vykreslí 4 ikony (velké emoji + název) a odpočet; každé 2 s GET `stav`: `pending` nic, `approved` → „Přihlásit jako <name>?“ s Ano / To nejsem já, `cancelled`/`none`/vypršení → hláška + „Nový kód“; Ano → POST `ano` → `location = url` / chyba; „Nový kód“ → znovu `vytvor`. Dotazování se zastaví v koncovém stavu.
- `init_device_login_keyboard`: klik na ikonu doplní další pole, „Smazat“ maže poslední; po 4. POST `kod` → při `ok` panel „Přihlásit <device>? Stejná síť jako ty: ano/ne. Kód vytvořen před N s.“ + „Potvrď, jen pokud to zařízení máš před sebou.“ + Potvrdit / Zrušit; jinak chyba a vyprázdnit pole. Potvrdit → „Hotovo, na druhém zařízení klikni Ano.“

- [ ] **Step 1: Ověřit vizuálně** v headless Chromiu (harness ve scratchpadu jako u adventomatu, `$.ajax` mock): obě obrazovky na šířce 900 a 380 px, stav approved, chyba kódu. Screenshoty jen ve scratchpadu.
- [ ] **Step 2: Ruční průchod v dev serveru** (pokud jde spustit): dva prohlížeče / anonymní okno, celý průběh.
- [ ] **Step 3: Suite PASS.**
- [ ] **Step 4: Commit** `přihlášení jiným zařízením: JS obou stran; tep.js?v=…`.

### Task 6: Dokumentace a připomínka

- [ ] Doplnit do specu sekci „Stav: implementováno“ s odkazem na commity (jedna věta).
- [ ] Připomenout Vítovi kontrolu HTTPS/cookies (paměť `tep-https-cookies-todo`) a upozornit, že nasazení potřebuje `make prod-migrate` (migrace 041).
