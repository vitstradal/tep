# Adventomat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adventomat 2026: zadání v piki, kalendář jako wiki stránka webu vykreslená JS z JSON API tepu, server drží otevírání, odpovědi, vyřešené dny, tabulku, debug orgů a kontrolu dnů; převod 2023–2025.

**Architecture:** `lib/adventomat.rb` parsuje piki stránku ročníku a počítá časy/kontrolu; `AdventomatController` vydává JSON (kalendář, den, obrázek, odměna, moje, odpověď, debug) a HTML kontrolu; makro `{{adventomat_kalendar <rok>}}` vloží kontejner a `init_adventomat_app` v `tep.js` kalendář vykreslí.

**Tech Stack:** Rails 7.2, CanCan, Rugged/Giwi, TracWiki, jQuery + Bootstrap 3 (ace).

**Spec:** `docs/superpowers/specs/2026-11-07-adventomat-design.md`

## Global Constraints

- Čas Europe/Prague; výchozí `otevírání` 3:14, `uzávěrka` 26. 12. 23:59, `v tabulce od` 4.
- Bonus = `question_no` 25, otevírá se s dnem 24.
- Quiz name `advent-<rok>`, piki stránka `adventomat/<rok>/index.wiki` ve wiki `piki`.
- Nic neotevřeného (text, obrázek, výsledek) nesmí opustit server; výsledek nikdy.
- Komentáře max. jeden řádek; žádné úpravy už spuštěných migrací.

## Review Focus

- Odpověď s mezerami („1 187“) nebo úvodní/koncovou mezerou → bere se jako číslo.
- Hranice času 3:13:59 / 3:14:00 v Praze (zimní čas, UTC+1).
- Host s uuid přítele napojeného na účet → odmítnout (ochrana existující v quiz).
- Obrázek odkazovaný ze dvou dnů → povolen, jakmile je otevřený kterýkoli z nich.
- Org bez debug módu hraje naostro (debug jen po zapnutí).

---

### Task 1: `Adventomat` — parser a časy

**Files:** Create `lib/adventomat.rb`; Modify `lib/giwi.rb` (public `get_blob(path) -> String|nil` raw bytes); Test `test/unit/adventomat_test.rb`

**Produces:**
- `Adventomat.quiz_name(year) -> "advent-#{year}"`, `Adventomat.year_of(name) -> Integer|nil`
- `Adventomat.load(year) -> Adventomat|nil` (piki), `Adventomat.parse(year, text, oid = nil)`
- `#days -> {Integer => Day}` (`Day = Struct(:no, :label, :text, :result, :note, :images)`), `#reward -> String|nil`, `#order -> [Integer]`
- `#open_at(no) -> Time`, `#open?(no, now)`, `#closes_at -> Time`, `#min_table -> Integer`, `#next_open_at(now) -> Time|nil`
- `#check_answer(no, raw) -> true|false|:not_number`
- `#render(text) -> html` (obrázky → `/quiz/advent-<rok>/obrazek/<soubor>`), `#day_html(no)`, `#reward_html`
- `#issues -> [{day:, level: :error|:warn, text:}]`

Tests: hlavička + výchozí hodnoty; dny 1, 5, bonus; `výsledek`/`poznámka` nejsou v `day_html`; obrázek přepsán; `open?` 3:13:59 false / 3:14 true (1. 12. Praha); bonus s 24; `check_answer('1 187')`; `:not_number` pro `abc`; `pořadí:` z hlavičky, jinak zamíchané stabilně podle roku (stejné při dvou voláních, obsahuje všechny dny); `issues` hlásí chybějící den, nečíselný výsledek, chybějící obrázek.

### Task 2: API kalendáře, dne, obrázku, odměny, moje

**Files:** Create `app/controllers/adventomat_controller.rb`, `app/controllers/concerns/friend_lookup.rb` (přesun `find_or_create_friend` z QuizController + `current_friend` bez zakládání); Modify `config/routes.rb`, `app/models/ability.rb`, `app/controllers/quiz_controller.rb`; Test `test/functional/adventomat_controller_test.rb`

Routy (před `get '/quiz/:name'`, `name: /advent-\d{4}/`): `GET kalendar`, `GET den/:den`, `GET obrazek/*soubor`, `GET odmena`, `GET moje`, `POST answer`, `POST debug`, `GET kontrola`.

Tests: kalendář před 1. 12. všechny `locked`, žádný text ani výsledek v JSON; `den` zamčeného 403, otevřeného HTML bez `výsledek`; obrázek neotevřeného dne 403, otevřeného 200 `image/png`; starý rok vše otevřené; `moje` přihlášený i host.

### Task 3: Odpovídání, „vyřešené zůstává“, tabulka, merge

**Files:** `app/controllers/adventomat_controller.rb#answer`, `app/controllers/friend_controller.rb#merge_friends`; Tests v `test/functional/adventomat_controller_test.rb`, `test/functional/friend_controller_test.rb`

Tests: správná odpověď → `solved`, pak špatná nepřepíše; ne-číslo 422 a nic neuloženo; zamčený den 403; tabulka jen ≥ min, `solved_at` po uzávěrce se nepočítá, řazení počet desc, nick asc; odměna jen po všech dnech; merge: vyřešený den hosta vyhraje nad nevyřešeným účtu.

### Task 4: Debug mód a kontrola dnů

**Files:** `AdventomatController#debug`, `#kontrola`, `app/views/adventomat/kontrola.html.erb`; Tests

Tests: org nastaví čas 24. 12. 3:14 → den 24 otevřený; ne-org debug ignorován (403); debug odpověď neuloží `QuizAnswer`, `moje` v debug vrací session; vypnutí vrátí skutečný čas; kontrola pro orga 200 s chybou nahoře, pro ne-orga 403.

### Task 5: Makro a frontend

**Files:** `app/controllers/giwi_controller.rb` (`adventomat_kalendar` → `<div id="adventomat-app" data-year="Y"></div>`), `public/javascripts/tep.js` (`init_adventomat_app`), CSS v `public/stylesheets` dle existujícího; Test makra v giwi testu

Kalendář: mřížka v pořadí `order`, ikony zámek/otazník/hvězda, odpočet, modál (zadání, pole, OK), přezdívka přes `friend_ensure`, localStorage `adventomat-<rok>`, tabulka, odměna, lišta debug pro orga.

### Task 6: Převod 2023–2025 a stránka 2026

**Files:** Create `script/adventomat_import.rb`; mění checkouty `~/git/web`, `~/git/piki` (commit, push dělá uživatel)

Ověření: pro každý rok piki stránka má 25 dnů s výsledky shodnými se starými makry; web stránka obsahuje makro a starou tabulku, ne `{{adventomat question`; `Adventomat.parse(...).issues` bez chyb. `web/adventomat/2026/index.wiki` s makrem; piki 2026 vzor bez `== úvod ==`.
