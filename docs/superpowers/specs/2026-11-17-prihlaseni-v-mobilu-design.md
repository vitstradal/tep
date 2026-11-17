# Přihlášení v mobilu přes QR z počítače

## Proč

Psát dlouhé heslo do mobilu je nepříjemné. Kdo je přihlášený v tepu na
počítači, má se do mobilu dostat naskenováním QR kódu a pár kliknutími, bez
hesla. Mobil = obyčejný prohlížeč (fotoaparát otevře odkaz z QR).

## Cíle a ne-cíle

- Cíl: přihlášení mobilu bez hesla, mobil pak zůstane přihlášený (rememberable,
  `remember_for = 1.year`), takže se párování dělá jen zřídka.
- Cíl: odolnost proti vyfocení / naskenování QR přes rameno.
- Ne-cíl: seznam přihlášených zařízení, odhlášení na dálku, opačný směr
  (start z mobilu), nativní aplikace, websockety.
- Anti-cíl: aby šel mobil přihlásit jen tím, že někdo naskenuje QR —
  rozhoduje až potvrzení na počítači.

## Postupy (zvažované)

- **A) Záznam párování v DB + dotazování obou stran po 2 s — vybráno.**
  Obyčejný Rails, zámek v DB zaručí, že kód zabere jediný telefon.
- B) Totéž přes ActionCable — okamžitá odezva, ale tep nemá websockety
  (další proces, nginx). Na 20 s akci zbytečné.
- C) Bez tabulky, jen podepsané tokeny a cache — tep nemá sdílenou cache
  s atomickými operacemi, „zabere jen jeden“ by bylo křehké.

Potvrzovací kód (rozhodnuto s uživatelem): místo PINu **4 emoji, na počítači
u každé pozice výběr ze 4** (1 správné + 3 návnady), pool 24 emoji.
Entropie 4 × 2 bity = 8 bitů, se 3 pokusy 1,2 % na trefu naslepo. Stačí to,
protože hádat může jen ten, kdo sedí u přihlášeného počítače (endpoint je
vázaný na vlastníka párování + CSRF), a útok by vyžadoval, aby uživatel
klikal naslepo, zatímco jeho telefon hlásí chybu. Skutečnou ochranu nese
128bitový jednorázový token, pravidlo „zabere jen první telefon“ a krátká
platnost.

## Průběh

1. **Počítač** (přihlášený): v uživatelském menu (vedle Logout) položka
   „Přihlásit se v mobilu“ → stránka `/mobil`. Vytvoří párování a ukáže QR
   s URL `https://<host>/m/<token>` a text „Naskenuj fotoaparátem mobilu“.
   Odpočet platnosti, tlačítko „Nový kód“.
2. **Mobil** naskenuje → `GET /m/<token>`. Atomicky zabere párování
   (`UPDATE … WHERE state = 'pending' AND expires_at > now`), uloží do
   httponly cookie náhodný identifikátor telefonu (v DB jen jeho SHA-256)
   a ukáže 4 emoji s názvy + „Vyber je na počítači“. Obnovení stránky
   stejným telefonem ukáže totéž.
3. **Jiný telefon** (nebo druhý sken s jinou cookie) na už zabrané párování
   → párování se **zruší** (stav `cancelled`, důvod „naskenovalo víc
   zařízení“), oba telefony i počítač to ukážou; počítač nabídne nový kód.
   Vypršelé / použité / neznámé tokeny → stejná chybová stránka.
4. **Počítač** (dotaz po 2 s) zjistí stav `claimed` a místo QR ukáže
   pozici 1 ze 4: čtyři tlačítka s emoji a názvem. Kliknutí vyplní pozici
   a ukáže další čtveřici; „Smazat“ vrátí o pozici zpět se **stejnou
   čtveřicí**. Po 4. výběru se odešle.
5. **Špatně** → pokus −1, návrat na pozici 1 (čtveřice stejné). Po 3
   chybách stav `cancelled`.
   **Správně** → stav `approved`, počítač ukáže „Mobil přihlášen ✓“.
6. **Mobil** (dotaz po 2 s) při `approved` a shodné cookie: `sign_in` toho
   uživatele s remember me, stav `done` (token už nejde použít), přesměruje
   na titulní stránku. Byl-li mobil přihlášený za někoho jiného, nejdřív
   odhlásit.

Čtveřice a správná emoji se losují **jednou na serveru při zabrání** a
dál se nemění (jinak by průnik dvou nabídek prozradil správné emoji).
Pořadí v čtveřici náhodné, správnost ověřuje jen server; počítač dostane
jen čtveřice (indexy do poolu), ne správné odpovědi.

## Platnost

- QR (stav `pending`): 2 minuty.
- Po zabrání: 3 minuty na výběr emoji a přihlášení mobilu.
- Staré záznamy (> 1 den) se mažou při vytváření nového párování.

## Data

Nová tabulka `phone_logins`:
`token_digest` (SHA-256 tokenu, unikátní), `user_id`, `state`
(`pending` / `claimed` / `approved` / `done` / `cancelled`),
`cancel_reason`, `device_digest`, `code` (JSON, 4 indexy do poolu),
`choices` (JSON, 4 × 4 indexy), `attempts_left` (3), `expires_at`,
timestamps. Token sám se neukládá.

## Emoji (pool 24, Unicode ≤ 9, bez obličejů, vlajek a VS16)

🍎 jablko, 🍌 banán, 🍇 hrozny, 🍉 meloun, 🥕 mrkev, 🍕 pizza, 🍄 houba,
🌵 kaktus, 🌻 slunečnice, 🌙 měsíc, ⭐ hvězda, 🔥 oheň, 🐘 slon, 🐟 ryba,
🐢 želva, 🐝 včela, 🐧 tučňák, 🦋 motýl, 🚗 auto, 🚲 kolo, 🚀 raketa,
⚽ míč, 🎸 kytara, 🔑 klíč.

Na obou stranách se pod emoji ukazuje český název (rozdílné kreslení na
různých systémech pak nevadí).

## Technika

- Controller `PhoneLoginController`; `/mobil*` jen přihlášený (ability),
  `/m/:token*` anonymní. Práva v `app/models/ability.rb`.
- QR jako SVG na serveru gemem `rqrcode` (nová závislost).
- Dotazování: jQuery, JSON endpointy, `setTimeout` 2 s; zastaví se po
  koncovém stavu nebo vypršení.
- Testy (functional): celý průběh, druhý sken zruší párování, vypršení,
  3 špatné pokusy, token nejde použít znovu, cizí uživatel nemůže
  posílat výběr k cizímu párování, smazání nemění čtveřice.

## Na stavitele

- Přesný vzhled stránek (Bootstrap 3 / ace jako zbytek tepu).
- Limit vytváření párování na uživatele (rozumný strop, např. 20 / hod).
- Texty hlášek.
