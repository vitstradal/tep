# Tep

Tep je webová aplikace pro uživatele a organizatory korespondenční soutěže
Pikomat MFF UK.

Hlavní moduly:

* Devise -- správa uživatelů, registrace, znovu zasílání hesel, skupiny a atd.
* Giwi -- stránky pikomatu pomocí wiki s git backendem
* Sosna -- upload elektonických řešení, evidnce bodů, vysledkové listiny.

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

