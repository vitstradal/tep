# Přihlášení přes QR mezi počítačem a mobilem

## Proč

Psát dlouhé heslo do mobilu je nepříjemné. Kdo je přihlášený v tepu na
jednom zařízení, má se na druhém přihlásit naskenováním QR kódu a pár
kliknutími, bez hesla. Mobil = obyčejný prohlížeč (fotoaparát otevře odkaz
z QR).

## Cíle a ne-cíle

- Cíl: přihlášený počítač → přihlásí mobil („Přihlásit se v mobilu“).
  Mobil pak zůstane přihlášený (rememberable, `remember_for = 1.year`),
  takže se párování dělá jen zřídka.
- Cíl: přihlášený mobil → přihlásí počítač („Přihlásit mobilem“ na
  přihlašovací stránce). Stejný průběh, jen opačný zdroj účtu.
- Cíl: odolnost proti vyfocení / naskenování QR přes rameno.
- Ne-cíl: seznam přihlášených zařízení, odhlášení na dálku, nativní
  aplikace, websockety, ruční naťukávání kódu.
- Anti-cíl: aby se dalo přihlásit jen tím, že někdo naskenuje QR —
  rozhoduje až výběr emoji na straně, která QR ukazuje.

## Postupy (zvažované)

- **A) Záznam párování v DB + dotazování obou stran po 2 s — vybráno.**
  Obyčejný Rails, zámek v DB zaručí, že kód zabere jediné zařízení.
- B) Totéž přes ActionCable — okamžitá odezva, ale tep nemá websockety
  (další proces, nginx). Na 20 s akci zbytečné.
- C) Bez tabulky, jen podepsané tokeny a cache — tep nemá sdílenou cache
  s atomickými operacemi, „zabere jen jeden“ by bylo křehké.
- Pro opačný směr zvažováno naťukání emoji z mřížky na mobilu bez QR —
  zamítnuto, stejný průběh s QR je jednodušší a odolnější proti phishingu.

Potvrzovací kód (rozhodnuto s uživatelem): místo PINu **4 emoji, na straně
s QR u každé pozice výběr ze 4** (1 správné + 3 návnady), pool 24 emoji
(mřížka 4×6, dost různorodá; velikost poolu entropii neovlivňuje).
Entropie 4 × 2 bity = 8 bitů, se 3 pokusy 1,2 % na trefu naslepo. Stačí to:
výběr jde poslat jen z prohlížeče, který QR vytvořil (cookie + CSRF), a útok
by vyžadoval klikání naslepo, zatímco skenující mobil hlásí chybu. Skutečnou
ochranu nese 128bitový jednorázový token, pravidlo „zabere jen první
zařízení“ a krátká platnost.

## Role a směr

- **Ukazující** = prohlížeč, který vytvořil párování a ukazuje QR; vybírá
  emoji. Identifikuje ho httponly cookie (v DB jen SHA-256).
- **Skenující** = prohlížeč, který otevřel `/m/<token>`; ukazuje emoji.
  Také cookie (v DB SHA-256).
- **Směr `send`** — ukazující je přihlášený (stránka `/mobil`, položka
  „Přihlásit se v mobilu“ v uživatelském menu vedle Logout). Účet =
  ukazujícího; po potvrzení se přihlásí skenující, s remember me.
- **Směr `receive`** — ukazující není přihlášený (stránka
  `/prihlaseni-mobilem`, odkaz „Přihlásit mobilem“ na přihlašovací
  stránce). Skenující musí být přihlášený, jinak hláška „V tomhle
  prohlížeči nejsi přihlášený“ (fotoaparát mohl otevřít jiný prohlížeč).
  Účet = skenujícího v okamžiku skenu; po potvrzení se přihlásí ukazující.
  Na stránce ukazujícího zaškrtávátko „Zůstat přihlášený“ (výchozí
  vypnuto — sdílené počítače); bez něj session do zavření prohlížeče.
- Směr určuje tlačítko, ze kterého párování vzniklo, a ukládá se v DB.

## Průběh

1. **Ukazující** vytvoří párování a ukáže QR s URL
   `https://<host>/m/<token>`, text „Naskenuj fotoaparátem mobilu“,
   odpočet platnosti a tlačítko „Nový kód“.
2. **Skenující** → `GET /m/<token>`. Atomicky zabere párování
   (`UPDATE … WHERE state = 'pending' AND expires_at > now`), uloží
   identifikátor skenujícího (u `receive` i jeho `user_id`), vylosuje kód
   a čtveřice a ukáže 4 emoji s názvy + „Vyber je na druhém zařízení“.
   Obnovení stránky stejným prohlížečem ukáže totéž.
3. **Jiné zařízení** (druhý sken s jinou cookie) na už zabrané párování →
   párování se **zruší** (stav `cancelled`, důvod „naskenovalo víc
   zařízení“), všichni to uvidí; ukazující nabídne nový kód.
   Vypršelé / použité / neznámé tokeny → stejná chybová stránka.
4. **Ukazující** (dotaz po 2 s) zjistí stav `claimed` a místo QR ukáže
   pozici 1 ze 4: čtyři tlačítka s emoji a názvem. Kliknutí vyplní pozici
   a ukáže další čtveřici; „Smazat“ vrátí o pozici zpět se **stejnou
   čtveřicí**. Po 4. výběru se odešle.
5. **Špatně** → pokus −1, návrat na pozici 1 (čtveřice stejné). Po 3
   chybách stav `cancelled`.
   **Správně** → stav `approved`.
6. **Přihlášení:**
   - `send`: skenující (dotaz po 2 s) při `approved` a shodné cookie →
     `sign_in` s remember me, stav `done`, přesměrování na titulní
     stránku; ukazující ukáže „Mobil přihlášen ✓“.
   - `receive`: ukazující hned po správném výběru → `sign_in` (remember
     podle zaškrtávátka), stav `done`, přesměrování na titulní stránku;
     skenující ukáže „Počítač přihlášen ✓“.
   Byl-li přihlašovaný prohlížeč přihlášený za někoho jiného, nejdřív
   odhlásit.

Čtveřice a správná emoji se losují **jednou na serveru při zabrání** a
dál se nemění (jinak by průnik dvou nabídek prozradil správné emoji).
Pořadí v čtveřici náhodné, správnost ověřuje jen server; ukazující dostane
jen čtveřice (indexy do poolu), ne správné odpovědi.

## Platnost

- QR (stav `pending`): 2 minuty.
- Po zabrání: 3 minuty na výběr emoji a přihlášení.
- Staré záznamy (> 1 den) se mažou při vytváření nového párování.

## Data

Nová tabulka `qr_logins`:
`token_digest` (SHA-256 tokenu, unikátní), `direction` (`send` /
`receive`), `user_id` (u `receive` doplněn při skenu), `state` (`pending`
/ `claimed` / `approved` / `done` / `cancelled`), `cancel_reason`,
`shower_digest`, `scanner_digest`, `remember` (bool, jen `receive`),
`code` (JSON, 4 indexy do poolu), `choices` (JSON, 4 × 4 indexy),
`attempts_left` (3), `expires_at`, timestamps. Token sám se neukládá.

## Emoji (pool 24, Unicode ≤ 9, bez obličejů, vlajek a VS16)

🍎 jablko, 🍌 banán, 🍇 hrozny, 🍉 meloun, 🥕 mrkev, 🍕 pizza, 🍄 houba,
🌵 kaktus, 🌻 slunečnice, 🌙 měsíc, ⭐ hvězda, 🔥 oheň, 🐘 slon, 🐟 ryba,
🐢 želva, 🐝 včela, 🐧 tučňák, 🦋 motýl, 🚗 auto, 🚲 kolo, 🚀 raketa,
⚽ míč, 🎸 kytara, 🔑 klíč.

Na obou stranách se pod emoji ukazuje český název (rozdílné kreslení na
různých systémech pak nevadí).

## Technika

- Controller `QrLoginController`; `/mobil` jen přihlášený, ostatní
  (`/prihlaseni-mobilem`, `/m/:token`, stavové a výběrové endpointy)
  anonymní s kontrolou cookie. Práva v `app/models/ability.rb`.
- QR jako SVG na serveru gemem `rqrcode` (nová závislost).
- Dotazování: jQuery, JSON endpointy, `setTimeout` 2 s; zastaví se po
  koncovém stavu nebo vypršení.
- Testy (functional), pro oba směry: celý průběh, druhý sken zruší
  párování, vypršení, 3 špatné pokusy, token nejde použít znovu, výběr
  z cizího prohlížeče (jiná cookie) se odmítne, smazání nemění čtveřice,
  `receive` se nepřihlášeným skenujícím, remember u `receive`.
- Pořadí stavby: nejdřív `send`, pak `receive` (sdílí většinu kódu).

## Na stavitele

- Přesný vzhled stránek (Bootstrap 3 / ace jako zbytek tepu).
- Limit vytváření párování (na uživatele u `send`, na IP u `receive`,
  rozumný strop, např. 20 / hod).
- Texty hlášek.
