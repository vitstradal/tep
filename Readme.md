# Tep

Tep je webová aplikace pro uživatele a organizatory korespondenční soutěže
Pikomat MFF UK.

Hlavní moduly:

* Devise -- správa uživatelů, registrace, znovu zasílání hesel, skupiny a atd.
* Giwi -- stránky pikomatu pomocí wiki s git backendem
* Sosna -- upload elektonických řešení, evidnce bodů, vysledkové listiny.
* Kvízy a přátelé Pikomatu -- sranda kvízy, adventomat, anonymní identity
  s nickem a registrace „přítel Pikomatu" (návrh: `navrh-kvizy-a-pratele.md`)

## Kvízy a přátelé Pikomatu

Detaily v `navrh-kvizy-a-pratele.md`. Rychlý přehled pro provoz:

* Nový kvíz se zakládá v konzoli (`make prod`):

  ```ruby
  Quiz.create!(name: 'advent-2026', quiz_type: 'advent', title: 'Adventní kalendář 2026',
               opens_on: Date.new(2026,12,1), closes_on: Date.new(2026,12,31),
               data: { 'correct' => { '1' => '42', '2' => 'sob' } })
  ```

  `quiz_type` je `quiz` | `advent` | `poll`; advent odemyká otázku (den) č. N
  až od `opens_on + N - 1`. `data['correct']` je nepovinné (anketa ho nemá).

* Adventomat na wiki stránce se napojí atributem `data-quiz="advent-2026"`
  na `#adventomat-modal`; bez atributu funguje postaru (jen localStorage).
* Odpovědi: `POST /quiz/<name>/answer`, výsledkovka: `GET /quiz/<name>/vysledky`.
* Registrace přítele: `/pritel`, dokončení mailovým linkem (platí 7 dní),
  neověřený účet je bez role a bez `confirmed_at`; admin je vidí ve filtru
  „bez role" na `/users/none`.
* Úklid (cron ~1× denně): `RAILS_ENV=production bundle exec rake friends:cleanup`
  -- maže anonymní friendy neaktivní >1 rok a neověřené účty >1 měsíc.

## Makefile

* `make` -- v produkci zpusobi restart serveru (aplikuji se provedene zmeny)
* `make doc` -- vygeneruje dokumentaci
* `make server` -- pusti server lokalne na `http://localhost:3000/`
* `make dev`, `make prod`, `make loc` -- spust cmdline ruby v kontextu prostredi
* `make test` -- pusti testy

## Tools

Pomocné skripty, bez argumetů napíšou stručný help.



* `script/aesob.rb`  -- Export z tepu pro aesob, `https://ovvp.mff.cuni.cz/wiki/aesop/import`

* `script/fotodir.pl` -- obsolete

* `script/load29.rb` -- obsolete

* `script/load-body.rb` naleje body z csv do db, doufejme ze obsolete.

* `script/pik2yaml.rb` -- nacte `.pik`, a vyplyvne v `.yaml`.

* `script/rails`

* `script/sqlitedump.pl` -- sqlitedump, ale takovy aby se dal pouzit pri upgradu, (insert i se jmeny sloupcu).

Je treba mít v `.bash_profile`

```
[[ -s "/usr/local/rvm/scripts/rvm" ]] && source "/usr/local/rvm/scripts/rvm"
```
