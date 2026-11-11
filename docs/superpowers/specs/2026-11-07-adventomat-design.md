# Adventomat — návrh (2026)

## Proč

Adventomat (otevírací kalendář s jedním matematickým příkladem denně, 1.–24. 12.
plus bonus) dosud žil jako wiki stránka na veřejném webu (`/adventomat2023`,
`/adventomat2024`, `/adventomat2025`). Zadání i výsledky byly parametry makra
`{{adventomat question|datum|text|výsledek|obrázek}}` přímo ve stránce, výsledek
jen „fakecrypt“-ovaný. Odpovědi chodily přes inform (`adventomat2025`),
vyřešené dny si pamatoval jen prohlížeč (localStorage `adventomat`) a tabulku
řešitelů skládal org ručně skriptem `script/adventomat.rb` a vkládal ji
do stránky.

Problémy, které nový adventomat řeší:

- zadání budoucích dnů jsou vidět dopředu (Ctrl-U) a výsledky jdou odšifrovat;
- okénka se odemykají jen podle data v prohlížeči;
- vyřešené dny nejsou vidět na jiném počítači;
- tabulka je ruční práce;
- orgové si nemůžou vyzkoušet otevírání a odpovídání před ostrým startem.

## Cíle

1. **Automatické otevírání** okének ve stejný, trochu vtipný čas každý den
   (výchozí **3:14** Europe/Prague), s odpočtem do dalšího okénka.
2. **Zachovaný formát**: příklad je text, někdy s obrázkem, výsledek je číslo,
   které hráč zadá a server zkontroluje. Okénko po vyřešení zezelená.
3. **Identita přes „přítele“** z kvízové infrastruktury
   (`navrh-kvizy-a-pratele.md`): host jen s přezdívkou v prohlížeči, kterého si
   později může zaregistrovat; přihlášený uživatel hraje pod svým účtem.
4. **Zadání píšou orgové do piki**, na veřejnou stránku je vydává tep
   („tunel“) — vždy jen dny, které už jsou otevřené.
5. **Nic dopředu**: ve zdroji stránky ani v žádné odpovědi serveru není
   zadání, obrázek ani výsledek dne, který ještě není otevřený. Výsledky
   neopouštějí server nikdy.
6. **Vyřešená okénka drží server**: přihlášený/registrovaný hráč vidí stejný stav
   na každém počítači; host jen v tom prohlížeči (dokud se nezaregistruje —
   pak se identity spojí přes existující `/friend/claim`).
7. **Tabulka se skládá sama** a v nastavený čas (výchozí 26. 12. 23:59) se
   uzavře. Řešit a kontrolovat jde i potom, jen se to do tabulky nepočítá.
8. **Debug mód pro orgy**: posun času a zkušební odpovídání bez zápisu.
9. **Kontrola dnů pro orgy**: přehled, jestli má každý den zadání, číselný
   výsledek a existující obrázky.
10. **Převod loňských kalendářů** 2023, 2024 a 2025 do nového formátu.

## Ne-cíle

- Počet pokusů ani čas odevzdání se nehodnotí (tabulka = počet vyřešených).
- Žádná nová obecná „hra“/engine; jde o adventomat nad existujícími tabulkami
  `quizzes`/`quiz_answers`/`friends`.
- Žádné šifrování v prohlížeči — utajení zajišťuje to, že server nepošle nic
  neotevřeného.
- Žádný import starých odpovědí z informů do `quiz_answers` (staré přezdívky
  jsou volný text bez identity; staré tabulky zůstanou jako statický text).

## Anti-cíle (selhání, i kdyby to „fungovalo“)

- Zadání nebo výsledek budoucího dne je k nalezení v HTML, JS, JSON nebo přes
  uhádnutou URL obrázku.
- Hráč přijde o vyřešené okénko (např. tím, že po správné odpovědi zadá
  špatnou, nebo že se přihlásí).
- Org musí při běžném provozu sahat do databáze nebo spouštět skript.
- Zkoušení orgů v debug módu se dostane do tabulky.

## Zdroj zadání: piki `/adventomat/<rok>/index.wiki`

Jedna stránka v piki na ročník. Obrázky leží vedle ní
(`/adventomat/<rok>/5.png` apod.). Piki je jen pro orgy, takže stránku
i obrázky si hráči přímo neotevřou.

Formát stránky (piki ji dál normálně zobrazuje i edituje):

```
= Adventomat 2026 =

název: Adventomat 2026
otevírání: 3:14
uzávěrka: 26. 12. 23:59
v tabulce od: 4

== 1 ==
Šrek 1. 12. vyrazil osvobodit princeznu Fionu. …
[[Image(1.png)]]
výsledek: 17
poznámka: au vitas, kontrola Klátra

== 2 ==
…
výsledek: 17

== bonus ==
…
výsledek: 225

== odměna ==
Ukáže se hráči, který má vyřešená všechna okénka (Šrek, Marvin…).
[[Image(odmena.png)]]
```

- Hlavička (řádky `klíč: hodnota` před první sekcí; jiný text před první sekcí je poznámka pro orgy a ignoruje se) je nepovinná; chybějící
  klíč = výchozí hodnota. `otevírání` je čas v Europe/Prague, `uzávěrka` datum
  a čas uzavření tabulky v daném roce, `v tabulce od` minimální počet
  vyřešených, aby byl hráč v tabulce.
- Den je sekce `== N ==` (1–24) nebo `== bonus ==`. Řádek `výsledek: N` je
  povinný (celé číslo, smí být záporné). Řádky `výsledek:` a `poznámka:` se
  hráčům nikdy neposílají; zbytek sekce je zadání ve wiki syntaxi.
- Den bez sekce se v kalendáři ukáže jako zamčené okénko „připravujeme“
  (a kontrola dnů ho hlásí).
- Den N se otevře **N. 12. v čas `otevírání`**; bonus spolu se dnem 24.
- Stránka je jediný zdroj pravdy (zadání, výsledky, nastavení). V DB je jen
  záznam `quizzes(name: 'advent-<rok>', quiz_type: 'advent')`, který se založí
  automaticky při prvním přístupu, a odpovědi.

## Veřejná stránka a tunel

Veřejná stránka je wiki stránka ve webu **`/adventomat/<rok>/index.wiki`**
(adresář ročníku, obrázky starých ročníků vedle ní; `/adventomat` přesměruje
na aktuální rok). Stránka obsahuje makro `{{adventomat_kalendar <rok>}}`,
které vloží jen prázdný kontejner `<div id="adventomat-app" data-year="<rok>">`.
Kalendář do něj vykreslí JS z JSON API tepu. HTML wiki stránky je tedy pro
všechny stejné (jde cachovat) a nic tajného v něm není. Úvod, pravidla a
obrázek ročníku píšou orgové do webové stránky kolem makra.

API v tepu (před `GET /quiz/:name`, `name` = `advent-<rok>`):

| Routa | Kdo | Co |
|---|---|---|
| `GET /quiz/advent-<rok>/kalendar` | všichni | JSON: dny (číslo, stav zamčeno/otevřeno/vyřešeno, čas otevření), pořadí okének, čas serveru a dalšího otevření (odpočet), tabulka, debug stav pro orga |
| `GET /quiz/advent-<rok>/den/:den` | všichni | JSON s HTML zadání otevřeného dne (403 a čas otevření, když ještě není) |
| `GET /quiz/advent-<rok>/obrazek/*soubor` | všichni | obrázek z piki, jen když na něj odkazuje už otevřený den, nebo odměna u hráče, který na ni má nárok |
| `GET /quiz/advent-<rok>/odmena` | všichni | HTML sekce odměna, jen když má aktuální přítel vyřešené všechny dny |
| `GET /quiz/advent-<rok>/moje` | všichni | JSON `{solved: [1, 5, …], nick:}` pro aktuálního přítele (přihlášený přes session, host přes `uuid`) |
| `POST /quiz/advent-<rok>/answer` | všichni | existující endpoint; u adventu kontroluje proti výsledku z piki |
| `GET /quiz/advent-<rok>/kontrola` | org | kontrola dnů (HTML stránka tepu) |
| `POST /quiz/advent-<rok>/debug` | org | zapnutí/vypnutí debug módu a nastavení času |

- Zadání se renderuje wiki parserem piki, odkazy na obrázky se přepíšou na
  tunelovou routu `/quiz/advent-<rok>/obrazek/…`.
- Starý rok (po 24. 12. toho roku) má všechna okénka otevřená všem, bez
  přihlášení; řešit a kontrolovat jde dál.
- Vzhled okének převezme dnešní (`btn-app`, ikony zámek/otazník/hvězda),
  modál pro zadání a odpověď zůstává. Lišta přítele je ta z layoutu.
- **Pořadí okének** je zamíchané jako ve skutečném adventním kalendáři:
  pevně podle roku (stejné pro všechny), nebo podle hlavičky
  `pořadí: 19, 16, 9, …, bonus` v piki. Převod starých ročníků jejich pořadí
  zachová.

## Odpovídání a vyřešená okénka

- Odpověď je číslo; mezery se ignorují. Něco jiného než celé číslo → hláška
  „Napiš jen číslo“ (nezapočítá se, neukládá se).
- Server porovná s výsledkem z piki a vrátí `correct`. Uloží se do
  `quiz_answers` (`question_no` = den, bonus = 25).
- **Jednou vyřešené zůstává vyřešené**: správná odpověď nastaví v `data`
  `solved_at`; pozdější odpověď na stejný den už záznam nepřepíše.
- Odpovídat jde jen na otevřený den (server, ne JS).
- Po načtení stránky si JS zavolá `moje` a obarví vyřešená okénka.
  localStorage zůstává jen jako rychlá kopie pro okamžité překreslení.
- Přihlášený hraje vždy pod svým kanonickým přítelem (jako dnes).
- Host bez přezdívky: při první odpovědi se ho modál zeptá na přezdívku
  (stávající mechanismus `/friend/hello`).
- Registrace hostů (`/friend/register`) je vypnutá kvůli botům a zůstává
  mimo tento projekt. Host má adventomat v jednom prohlížeči; na více
  počítačích potřebuje účet (přihlášení spojí identity přes `/friend/claim`).
- Při přihlášení se tep dál ptá „Připojit k účtu?“ (sdílený počítač
  v rodině). Při spojení identit **vždy vyhraje vyřešený den** — u adventních
  kvízů vyhraje odpověď se `solved_at`, ostatní kvízy beze změny.

## Tabulka

- Řádek = přítel, počet dnů s `solved_at` ≤ uzávěrka; jen hráči s aspoň
  `v tabulce od` vyřešenými. Řazení podle počtu, při shodě abecedně podle nicku
  (s diskriminátorem při kolizi, jako výsledkovka kvízů).
- Do uzávěrky se tabulka počítá živě, potom je zamrzlá s nadpisem
  „Pořadí k <uzávěrka>“ a poznámkou, že řešit jde dál.
- Orgové jsou v tabulce jako ostatní hráči (*rozhodnutí návrhu*; 2025 v ní
  orgové byli).
- Převedené ročníky živou tabulku nemají (staré odpovědi jsou v informech);
  jejich stará tabulka zůstává jako text ve webové stránce.

## Debug mód (jen org)

- Na stránce kalendáře vidí přihlášený org lištu „debug“.
- **Posun času**: org nastaví datum a čas; server pak všude (otevírání,
  odpočet, tunel zadání i obrázků, odměna) počítá s tímto časem. Čas se drží
  v session a uplatní se jen u přihlášeného orga. Nastavený čas dál běží.
  Tlačítko „Další den“ skočí 10 s před otevření dalšího zavřeného okénka,
  takže je vidět odpočet i animace odemčení. Tlačítko vrátí skutečný čas.
- **Zkušební odpovědi**: v debug módu se odpověď zkontroluje stejně jako
  naostro, ale neuloží se do `quiz_answers`. Vyřešené dny v debug módu se
  drží v session a po vypnutí debugu zmizí.
- Debug je viditelně označený (lišta jinou barvou), aby org nezapomněl, že
  nehraje naostro.

## Animace

- Odemčení: zprava přiletí klíč, zasune se do zámku, otočí se kolem své osy
  a zámek odletí; pod ním je otazník.
- Správná odpověď: otazník se rozprskne na malé barevné otazníky, které jako
  ohňostroj s gravitací odletí, a okénko je zelené s hvězdou.
- Při `prefers-reduced-motion` se okénka jen přepnou.

## Kontrola dnů (jen org)

Stránka `/quiz/advent-<rok>/kontrola` (styl jako Kontrola wiki akcí): řádek na
den 1–24 + bonus + odměna, s chybami nahoře:

- chybí sekce dne (chyba);
- chybí nebo není celé číslo `výsledek` (chyba);
- odkazovaný obrázek v piki neexistuje (chyba);
- prázdné zadání (varování);
- hlavička s nečitelným časem/datem (chyba);
- u každého dne náhled zadání a kdy se otevře.

Odkaz na kontrolu a debug je i v piki stránce (makro nebo ruční odkaz) a na
veřejné stránce pro orgy.

## Převod loňských kalendářů

Jednorázový skript `script/adventomat_import.rb` nad lokálními checkouty
`web` a `piki` pro 2023, 2024, 2025 (výsledek zkontroluje a pushne org):

- přečte `web/adventomat/<rok>/index.wiki` (makra
  `{{adventomat question|datum|text|výsledek|obrázek}}`), den vezme z data
  („1. 12.“ → 1, „bonus“ → bonus) a pořadí maker uloží jako `pořadí:`;
- vyrobí piki `adventomat/<rok>/index.wiki` ve formátu výše (dny, výsledky,
  `== odměna ==` — 2024 Marvin z `adventomat/2024/marvin.wiki`, 2023
  a 2025 bez odměny, protože ve webu žádná není);
- zkopíruje obrázky zadání z webu do piki (`web/adventomat/2025/5.png` →
  piki `adventomat/2025/5.png`) a přepíše odkazy; ve webu obrázky zůstanou;
- ve webové stránce nahradí blok maker a starý modál s informem makrem
  `{{adventomat_kalendar <rok>}}`; úvod a stará tabulka zůstanou;
- staré piki `adventomat/index.wiki` (návrhy příkladů 2025) zůstane, jak je.

Po převodu se otevře kontrola dnů pro každý rok a org opraví, co parser
nepobral.

## Omezení

- Rails 7.2 tep, CanCan, Devise; Postgres na produkci, SQLite v testech.
- Piki má `read: :org`; tunel čte přes `Giwi` server-side.
- Wiki cache (`Rails.cache` při `wiki_do_cache_parse`) nesmí podržet zadání
  déle, než má — klíč cache musí zahrnovat oid stránky.
- Migrace jen nové (nic se nemění na už spuštěných); deploy dělá uživatel
  (`make release`, `make prod-migrate`).

## Rozhodnutí návrhu (ne uživatele) — ke kontrole

- Čas otevírání **3:14** Europe/Prague (nastavitelný v hlavičce).
- Bonus se otevírá s 24. dnem; v DB má `question_no` 25.
- Uzávěrka tabulky výchozí **26. 12. 23:59**, minimum do tabulky **4**.
- Orgové jsou v tabulce normálně.
- Staré odpovědi z informů se neimportují; staré wiki stránky zůstanou.
- Odpověď „ne-číslo“ se neukládá.
- `uzávěrka` smí mít i rok (2024 a 2025 se tabulka uzavírala po Novém roce); bez roku = rok kalendáře.
- Odměna se ukáže po vyřešení všech 24 dnů i bonusu.
- localStorage má klíč podle roku (`adventomat-2026`), aby se nepletl se starým `adventomat` ze stránek 2023–2025.

## Na stavitele

- Přesná podoba parseru sekcí, struktura controlleru (nový `AdventomatController`
  vs. rozšíření `QuizController`), jak se přepisují obrázky v HTML.
- Vzhled stránky, odpočtu a debug lišty (v duchu dnešního ace layoutu).
- Jak přesně se obrazovka modálu ptá na přezdívku a navazuje na lištu přítele.
- Testy: parser, otevírání podle času (včetně hranice 3:13/3:14), tunel 403
  pro neotevřený den a obrázek, `moje` pro přihlášeného i hosta, „vyřešené
  zůstává“, debug neukládá, kontrola dnů, import roku 2025 na vzorku.
