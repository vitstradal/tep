# Návrh: kvízy, adventomat a přátelé Pikomatu

Datum: 2026-07-13. Stav: návrh k diskusi (před implementací).

## 1. Cíle

1. Nepřihlášený návštěvník si na stránkách může zvolit nick a hrát „sranda kvízy"
   a adventní kalendáře. Nick žije v prohlížeči (localStorage) — server nechce
   heslo ani registraci. Návštěvník se objevuje v pseudo-výsledkovkách.
2. Na návštěvníka s nickem „svítí" v horní liště výzva, aby se registroval:
   buď jako **přítel Pikomatu** (stačí email), nebo jako **řešitel** aktuálního
   ročníku (existující přihláška).
3. Přítel Pikomatu dokončí registraci klikem na mailový link (platnost 7 dní).
   Do té doby je **neověřený** — vše může používat (přes localStorage identitu),
   jen je tak označen. Po ověření si nastaví heslo, může se přihlašovat a
   později se stát řešitelem.
4. Přihlášení má být trvanlivé („jako Facebook") — běžný uživatel zůstává
   přihlášen téměř bez expirace.

## 2. Žebřík identit

Klíčové rozhodnutí: **stav ověření a role se nemíchají**. Nezavádí se žádná
nová role; „být přítel Pikomatu" je fakt (řádek v tabulce `friends`), ne
oprávnění.

| Stupeň            | Reprezentace                                              |
|-------------------|-----------------------------------------------------------|
| anonymní přítel   | řádek ve `friends` (uuid + nick), `user_id` NULL          |
| neověřený         | `friends.user_id` → `users`, ale `confirmed_at IS NULL`   |
| ověřený přítel    | user potvrzen (má heslo), `roles_mask` prázdná (bez role) |
| řešitel           | navíc role `:user` (přidá ji registrace řešitele)         |
| org, morg, admin… | beze změny                                                |

Role `:jabber` zůstává (bitů je dost, nerušíme, nepřejmenováváme). Pořadí
v `roles :admin, :org, :user, :guest, :sklep, :morg, :jabber` se nesmí měnit
(bitmaska `roles_mask`).

## 3. Datový model — tři nové tabulky

### `friends` — identita v kvízovém světě

```ruby
create_table :friends do |t|
  t.text        :uuid, null: false     # generuje server, prohlížeč drží v localStorage
  t.text        :nick, null: false
  t.bigint      :user_id               # NULL = anonymní; po registraci FK -> users
  t.timestamptz :last_seen_at
  t.timestamps
  t.index :uuid,    unique: true
  t.index :user_id, unique: true       # 1:1 — user má právě jednoho frienda
end
```

- `uuid` funguje jako bearer token anonymní identity: kdo ho zná, může
  odpovídat pod tímto nickem. Pro sranda kvízy přijatelné; uuid se nikdy
  nezobrazuje ve výsledkovkách celý (viz §10 rozlišení kolizí nicků).
- `user_id` je **unikátní**: každý uživatel má nejvýš jeden `friends` řádek
  (kanonický nick pro kvízy). Srážky z více zařízení řeší merge (§7).

### `quizzes` — definice aktivity

Společný jmenovatel pro kvíz, adventní kalendář i anketu: adventomat je kvíz
s otázkami odemykanými po dnech, anketa je kvíz bez správných odpovědí.

```ruby
create_table :quizzes do |t|
  t.text  :name, null: false     # čitelný identifikátor do URL i wiki: 'advent-2026'
  t.text  :quiz_type             # 'quiz' | 'advent' | 'poll'
  t.text  :subtype               # jemnější členění dle potřeby (volitelné)
  t.text  :title                 # lidský název: 'Adventní kalendář 2026'
  t.date  :opens_on, :closes_on  # okno, kdy lze odpovídat (server-side vynucení)
  t.jsonb :data                  # definice otázek, správné odpovědi, nastavení
  t.timestamps
  t.index :name, unique: true
end
```

Otázky a správné odpovědi žijí v `data` (jsonb) — schéma DB se nemění s každým
novým typem kvízu. Obsah/HTML kvízu může dál žít na wiki (Giwi), `quizzes`
řádek je jeho serverová kotva pro sběr odpovědí.

### `quiz_answers`

```ruby
create_table :quiz_answers do |t|
  t.bigint  :quiz_id,   null: false   # FK -> quizzes
  t.bigint  :friend_id, null: false   # FK -> friends (VŽDY, i pro přihlášené)
  t.integer :question_no
  t.text    :answer
  t.jsonb   :data                     # čas, počet pokusů, detaily
  t.timestamps
  t.index [:quiz_id, :question_no, :friend_id], unique: true
end
```

Identita jde **vždy přes `friend_id`**, žádné dvojité FK na `users`:
přihlášený uživatel odpovídá přes svého frienda (`friends.user_id`). Historie
odpovědí tak beze změny dat přežije upgrade z anonyma na účet. Výsledkovka je
jeden join `quiz_answers → friends` (+ `users` pro příznak ověření).

## 4. Identita v prohlížeči

- localStorage drží `{uuid, nick}` — jen **cache** pro předvyplnění a pro
  hlavičkový widget. Autorita je server (`friends`).
- Friend vzniká lazy: při prvním odeslání odpovědi (nebo uložení nicku) server
  vygeneruje uuid, založí řádek a vrátí uuid prohlížeči.
- JSON endpoint `GET /friend/status` (parametr uuid): vrací nick a stav
  (`anonymous` / `unverified` / `verified`), pro hlavičkový widget (§5).
  Přihlášenému uživateli odpovídá podle session, uuid ignoruje.

## 5. Horní lišta (ace-nav) — čtyři stavy

Widget na místě dnešního „Přihlášení" v `app/views/layouts/application.html.erb`;
stav si zjišťuje JS z localStorage + `/friend/status`:

1. **Nepřihlášen, žádný nick** — jako dnes: odkaz „Přihlášení".
2. **Nepřihlášen, nick v localStorage** — zobrazí se nick + upoutávka
   (vykřičník / badge, prvky ace-admin tématu), rozklik: „Zaregistruj se jako
   přítel Pikomatu (stačí email)" / „Staň se řešitelem" / „Přihlásit se".
3. **Registrovaný, neověřený** (uuid má `friends.user_id`, user nepotvrzen) —
   nick + výstražný trojúhelníček: „Dokonči registraci — koukni do mailu",
   s tlačítkem **znovu poslat dokončovací link** (Devise resend confirmation).
4. **Přihlášen** — jako dnes (email/nick uživatele), bez upoutávek.

**Přihlášený vyhrává**: když se potká přihlášená session s localStorage
friendem, platí identita ze session. localStorage se přepíše uuid+nickem
kanonického frienda přihlášeného uživatele (a případný cizí anonymní friend
v localStorage se nabídne k merge, §7).

## 6. Registrace přítele a ověření

Flow (nový controller, např. `FriendController`):

1. Formulář: email (nick předvyplněn z localStorage). 
2. Server založí `User` (bez role, `name` prázdné — nick žije ve `friends`),
   propojí `friends.user_id`, pošle **Devise confirmation** mail.
   `confirm_within` se zvedne z 2 na **7 dní** — bezpečné: dnešní solver flow
   confirmable stejně obchází (`user.confirm` natvrdo v
   `Sosna::SolverController#create`).
3. Dokončovací stránka (klik na link): potvrdí email **a v tomtéž kroku** nechá
   nastavit heslo (obdoba dnešních `first_login_instructions`). Pak normální
   Devise login.
4. Vypršelý link → stav 3 v liště nabízí resend.

Kolize emailů (oba směry):

- **Přítel zadá email, který v `users` už je** → účet se nezakládá; poslat
  mail „účet už máš, přihlas se / resetuj heslo" (bez prozrazení existence
  účtu ve webové odpovědi — anti-enumeration). Po přihlášení se friend
  propojí (§7).
- **Registrace řešitele s emailem neověřeného přítele** → solver flow účet
  převezme: `user.confirm` + `send_first_login_instructions` jako dnes,
  přidá `:user`; `friends` řádek zůstává.

## 7. Propojení a merge

- Po přihlášení server pushne do localStorage uuid+nick kanonického frienda
  uživatele → kvízová identita funguje i na novém zařízení.
- Když má uživatel v localStorage **cizí anonymní** friend uuid (hrál
  nepřihlášen na tomhle zařízení) a přihlásí se: nabídnout **merge** —
  `quiz_answers.friend_id` anonymního frienda se přepojí na kanonického,
  anonymní řádek se smaže. Duplicitní odpovědi (unique index) se zahazují ve
  prospěch kanonických. Nemá-li uživatel frienda ještě žádného, anonymní se
  prostě adoptuje (`user_id` se doplní).

## 8. Role a Ability — změny

1. `User#before_create { roles << :user }` **zrušit**; roli `:user` přiděluje
   explicitně registrace řešitele (`Sosna::SolverController#create`) a admin
   zakládání (`TepController#user_new`). Stávajících uživatelů se to nedotkne
   (`:user` už mají).
2. `Ability` doplnit:
   - anonym (`User.new`): `create` na `QuizAnswer` (přes uuid), čtení
     otevřených `quizzes` a výsledkovek;
   - přihlášený kdokoli (`user.persisted?`, bez ohledu na role): totéž pod
     účtem + správa vlastního `friends` řádku (změna nicku);
   - org: čtení odpovědí, moderace nicků (skrýt/přejmenovat ve výsledkovce);
   - morg: CRUD `quizzes`.
3. Admin výpis uživatelů (`TepController#users`) filtruje bitmaskou
   (`roles_mask & ? > 0`) — uživatel bez role by nebyl vidět v žádném filtru.
   Přidat filtr „bez role (jen přítel)" (`roles_mask = 0 OR roles_mask IS NULL`).

## 9. Politika přihlášení (cookies)

Cíl: každý je přihlášený „skoro napořád" — platí pro všechny účty včetně
org/morg/admin, žádné výjimky.

- Odebrat `:timeoutable` úplně (dnes `timeout_in 60.minutes`).
- `:rememberable`: `remember_for 1.year`, `extend_remember_period = true`
  (klouzavé prodlužování), checkbox „pamatuj si mě" defaultně zaškrtnutý
  (nebo rovnou vynechat a pamatovat vždy).

## 10. Nicky

- **Tři místa, tři významy** — není to redundance:
  - `friends.nick` — jediný zdroj pravdy pro kvízový svět, i po registraci
    (výsledkovka nikdy nesahá do `users` pro jméno);
  - `act_participants.nickname` — táborová přezdívka, jiný kontext, žádná
    synchronizace (nanejvýš UI prefill při zakládání);
  - localStorage — jen cache (§4).
- Unikátnost nicků se **nevynucuje** — rozlišuje uuid. Ve výsledkovce se
  kolize (Petr vs. Petr) rozliší krátkým veřejným diskriminátorem
  (např. `Petr ·a3`), odvozeným hashem z uuid — ne uuid samotným, aby neleakl.
- Moderace: délkový limit, ořez whitespace; org může nick ve výsledkovce
  skrýt/přejmenovat (sprosťárny).
- Ověřenost ve výsledkovce: friend s potvrzeným userem dostane fajfku/odznak,
  neověřený je označen „neověřen".

## 11. Adventomat — migrace

Dnes žije čistě ve frontendu (`public/javascripts/tep.js`, localStorage klíč
`adventomat`, HTML z wiki). Nově:

- založí se `quizzes(quiz_type: 'advent', name: 'advent-2026', …)`;
- JS začne vyřešené dny POSTovat jako `quiz_answers` (question_no = den);
- localStorage `adventomat` zůstává jako cache/fallback (funguje i bez nicku,
  jen bez výsledkovky);
- server-side kontrola, že odemykaný den už nastal a kvíz je otevřený
  (`opens_on`/`closes_on`) — ne jen v JS.

## 12. Anti-abuse a retence (GDPR)

- Anonymní POST odpovědí: rate-limit (např. rack-attack) + honeypot pole;
  validace otevřenosti kvízu na serveru.
- `friends` bez `user_id` a bez aktivity (`last_seen_at`) > 1 rok: smazat
  včetně odpovědí (pseudonymní data, ale ať se nehromadí).
- Neověřené `users` (nepotvrzené, bez jiných vazeb) > 1 měsíc: smazat,
  `friends.user_id` vynulovat (friend se vrací do anonymního stavu).
- Nick + uuid je pseudonym; email v `users` je osobní údaj — pokrývá stávající
  režim (stejně jako u řešitelů).

## 13. Co záměrně neřešíme (YAGNI)

- Vyhodnocování správnosti odpovědí na serveru pro všechny typy kvízů —
  začíná se sběrem odpovědí; vyhodnocení může být per-kvíz (v `data`).
- Přihlašování magic-linkem bez hesla.
- Propojování `friends` ↔ `solvers` historicky (řešitel má údaje per ročník,
  friend je nadčasový — vazba jde vždy přes `users`).
- Nick v `users` — občanské jméno (`name`, `last_name`) zůstává, kvízový nick
  je jen ve `friends`.

## 14. Hrubé etapy implementace

1. **DB + modely**: migrace `friends`, `quizzes`, `quiz_answers`; modely,
   validace, asociace (`User has_one :friend`).
2. **Sběr odpovědí**: endpointy pro založení frienda, `/friend/status`,
   POST odpovědi; napojení adventomatu.
3. **Lišta**: čtyřstavový widget v layoutu (ace-admin prvky).
4. **Registrace přítele**: FriendController, confirmable na 7 dní,
   dokončovací stránka (confirm + heslo), resend; kolize emailů.
5. **Role/Ability + cookies**: zrušení plošného `:user`, admin filtr,
   per-user timeout, remember 1 rok.
6. **Výsledkovky + moderace**: zobrazení, diskriminátory, org nástroje.
7. **Úklid**: rake task/cron na retenci (§12).
