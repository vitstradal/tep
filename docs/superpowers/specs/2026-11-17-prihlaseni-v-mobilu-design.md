# Přihlášení pomocí jiného (už přihlášeného) zařízení

## Proč

Psát dlouhé heslo do mobilu je nepříjemné. Kdo je přihlášený v tepu na
jednom zařízení (počítač nebo mobil), má se na druhém přihlásit opsáním
4 ikon, bez hesla. Funguje stejně v obou směrech, bez QR a fotoaparátu.
Stejný princip jako přihlášení televize k Netflixu/YouTube.

## Cíle a ne-cíle

- Cíl: nové zařízení ukáže 4 ikony, uživatel je zadá na už přihlášeném
  zařízení a nové zařízení se přihlásí (do zavření prohlížeče).
- Cíl: jednoduchost. Uživatel vědomě akceptuje zbytková rizika níže.
- Ne-cíl: QR kód, seznam přihlášených zařízení, odhlášení na dálku,
  nativní aplikace, websockety.

## Postupy (zvažované)

- **Kód ukazuje nové zařízení, zadává se na přihlášeném — vybráno.**
  Bez fotoaparátu, oba směry stejně, nejméně kódu.
- QR na přihlášeném zařízení + výběr 4 emoji ze čtveřic na něm (odolné
  proti vyfocení přes rameno díky „zabere jen první“) — zamítnuto,
  složitější (QR gem, fotoaparát může otevřít jiný prohlížeč).
- Technicky: záznam v DB + dotazování nového zařízení po 2 s (ne
  ActionCable — tep nemá websockety; ne cache — tep nemá sdílenou cache).

## Rizika a pojistky (rozhodnuto: akceptovatelné)

- **Phishing** — útočník pošle oběti kód ze svého zařízení („zadej tohle
  v tepu“) a po zadání je přihlášený jako oběť. Pojistka: po zadání kódu
  přihlášené zařízení ukáže popis nového zařízení (systém, prohlížeč, IP,
  stáří kódu) a „Potvrď, jen pokud to zařízení máš před sebou“ +
  tlačítko Potvrdit.
- **Odkoukání přes rameno** — útočník zadá kód oběti dřív a nové zařízení
  oběti se přihlásí za útočníka. Pojistka: nové zařízení před dokončením
  ukáže „Přihlásit jako <jméno>?“ s Ano / To nejsem já.
- **Hádání** — 24⁴ ≈ 330 000 kombinací, hádat jde jen z přihlášené
  session, trefa by jen přihlásila cizí zařízení za útočníka. Limit:
  5 neúspěšných zadání za minutu a 20 za hodinu na uživatele.

## Průběh

Na pořadí nezáleží: uživatel může začít na kterékoli straně. Kód vzniká
až otevřením stránky na novém zařízení, klávesnice na přihlášeném
zařízení nic nevytváří ani nečeká.

Názvy stran (rozhodnuto): přihlášená strana „Přihlásit na jiném
zařízení“, nepřihlášená strana „Přihlásit pomocí jiného zařízení“ —
název je sám o sobě trochu mlhavý, vyjasní ho text na stránce, která se
po kliknutí ukáže.

1. **Nové zařízení**: na přihlašovací stránce pod formulářem (pod
   tlačítkem Přihlásit) odkaz „Přihlásit pomocí jiného zařízení“ → `/prihlasit-zarizenim`. Vytvoří záznam a ukáže
   4 ikony s názvy (velké, dobře čitelné) a text „Zadej tyto 4 obrázky na
   zařízení, kde jsi přihlášený, v menu „Přihlásit na jiném zařízení“.“
   Odpočet platnosti, „Nový kód“. Odkaz přenese `next` / uloženou
   adresu (Devise `stored_location_for`), aby se po přihlášení šlo zpět.
2. **Přihlášené zařízení**: v rozbalovacím menu pod uživatelem (e-mail
   v horní liště) položka „Přihlásit na jiném zařízení“ → `/prihlasit-zarizeni`. Klávesnice 24 ikon (mřížka
   4×6, ikona + název), 4 pole, „Smazat“. Po 4. ikoně se odešle.
   Nad klávesnicí text: „Na novém zařízení dej na přihlašovací stránce
   „Přihlásit pomocí jiného zařízení“ a sem zadej 4 obrázky, které se ti
   tam ukážou.“
3. Server najde platný záznam ve stavu `pending` s tímto kódem.
   Nenalezen → „Kód neplatí nebo vypršel“, počítá se jako neúspěch do
   limitu. Nalezen → ukáže popis nového zařízení + Potvrdit / Zrušit.
4. **Potvrdit** → stav `approved`, `user_id` = přihlášený uživatel
   (atomicky `UPDATE … WHERE state = 'pending' AND expires_at > now`).
   Zrušit → `cancelled`.
5. **Nové zařízení** (dotaz po 2 s, identifikace httponly cookie, v DB
   jen SHA-256) při `approved` ukáže „Přihlásit jako <jméno>?“:
   Ano → `sign_in` **bez remember me** (session do zavření prohlížeče, pro
   všechny — rozhodnuto), stav `done`, mail vlastníkovi účtu (níže),
   přesměrování tam, kam uživatel mířil (níže). To nejsem já → `cancelled`.
   Byl-li prohlížeč přihlášený za někoho jiného, nejdřív odhlásit.

## Platnost a kódy

- Kód platí 5 minut od vytvoření (pokrývá přechod k druhému zařízení).
- Kód = 4 ikony z poolu 24, opakování povoleno; mezi platnými `pending`
  záznamy unikátní (při kolizi vylosovat znovu).
- Staré záznamy (> 1 den) se mažou při vytváření nového.
- Limit vytváření kódů: 30 / hod na IP (IPv6 /64).

## Data

Nová tabulka `device_logins`: `code` (string, 4 indexy do poolu, např.
`3-17-0-22`), `state` (`pending` / `approved` / `done` / `cancelled`),
`user_id` (při potvrzení), `device_digest` (SHA-256 cookie nového
zařízení), `user_agent`, `ip`, `return_to` (lokální cesta nebo NULL), `approved_at`,
`expires_at`,
timestamps. Neúspěšná zadání kódu pro limit: tabulka
`device_login_failures` (`user_id`, `created_at`) nebo ekvivalent v DB.

## Ikony (pool 24, Unicode ≤ 9, bez obličejů, vlajek a VS16)

🍎 jablko, 🍌 banán, 🍇 hrozny, 🍉 meloun, 🥕 mrkev, 🍕 pizza, 🍄 houba,
🌵 kaktus, 🌻 slunečnice, 🌙 měsíc, ⭐ hvězda, 🔥 oheň, 🐘 slon, 🐟 ryba,
🐢 želva, 🐝 včela, 🐧 tučňák, 🦋 motýl, 🚗 auto, 🚲 kolo, 🚀 raketa,
⚽ míč, 🎸 kytara, 🔑 klíč.

Všude se pod ikonou ukazuje český název (rozdílné kreslení na různých
systémech pak nevadí).

## Technika

- Controller `DeviceLoginController`. `/prihlasit-zarizenim` a jeho
  stavový/potvrzovací endpoint anonymní s kontrolou cookie;
  `/prihlasit-zarizeni` jen přihlášený. Práva v `app/models/ability.rb`.
- Odkaz pod formulářem v `app/views/devise/sessions/new.html.erb`.
- Položka v menu pod uživatelem v `app/views/layouts/application.html.erb`:
  dnes je rozbalovací jen pro admin/morg (`view_as_allowed?`), ostatním je
  to obyčejný štítek — udělat z něj dropdown pro všechny (položka „Přihlásit
  na jiném zařízení“ pro každého, přepínač „Jak to vidí“ dál jen pro
  `view_as_allowed?`). Zobrazovat `real_user.email`; na mobilu je e-mail
  `hidden-xs`, menu je pod ikonou uživatele.
- Dotazování: jQuery, JSON endpoint, `setTimeout` 2 s; zastaví se po
  koncovém stavu nebo vypršení.
- Popis zařízení z User-Agent jednoduchým rozpoznáním (Android / iPhone /
  Windows / Mac / Linux + Chrome / Firefox / Safari / Edge), bez gemu.
- Testy (functional): celý průběh, neplatný/vypršelý kód, limit
  neúspěchů, zrušení na obou stranách, kód nejde použít znovu, cizí
  prohlížeč (jiná cookie) nedostane přihlášení, žádná remember cookie,
  návrat na `return_to`, mail odeslán,
  unikátnost kódů mezi platnými.

## Návrat a upozornění (rozhodnuto)

- **Kam po přihlášení**: na `return_to` = `params[:next]` nebo Devise
  `stored_location_for(:user)` (tam ho ukládá OIDC re-login, takže se
  rovnou pokračuje do klepu/sklepu/preklepu), jen lokální cesta začínající
  `/` (ne `//`); jinak titulní stránka. Když se vracíme, hláška „Jsi
  přihlášený, pokračuješ tam, kam jsi mířil“; kdyby návrat nešel, hláška
  „Jsi přihlášený — to, co jsi dělal předtím, zopakuj“.
- Stejnou bezpečnou logiku použít i v `after_sign_in_path_for` (dnes
  ignoruje `stored_location_for`, takže se ztrácí návrat z OIDC i při
  přihlášení heslem, a `params[:next]` nekontroluje — otevřené
  přesměrování).
- **Mail** při každém přihlášení přes jiné zařízení: „Přihlásil ses na
  <systém · prohlížeč> <čas>. Pokud jsi to nebyl ty, změň si heslo.“
- **Bez remember me pro všechny**: nové zařízení zůstane přihlášené jen do
  zavření prohlížeče. (Mobilní prohlížeče se zavírají zřídka, v praxi to
  často vydrží dny.)

## Detaily z revize (rozhodnuto při návrhu)

- **CSRF**: vytvoření kódu, zadání kódu, Potvrdit, Ano i To nejsem já jsou
  POST s authenticity tokenem; controller `protect_from_forgery with:
  :exception`. Stránka nového zařízení se otevře GETem a kód vytvoří
  automatickým POSTem z JS (náhledy odkazů, prefetch a reload bez JS
  nevytvářejí záznamy).
- **Vazba kroků**: Potvrdit posílá `id` záznamu (ne kód); UPDATE má
  `id`, `state = 'pending'`, `expires_at > now`. Schvaluje `real_user`
  (ne `current_user`, který může být kopie z „Jak to vidí“).
- **Lhůta po schválení**: `approved_at`; Ano platí jen 2 min po schválení,
  atomicky `UPDATE … SET state = 'done' WHERE id = ? AND device_digest = ?
  AND state = 'approved' AND approved_at > now - 2 min`, `sign_in` jen když
  změnil 1 řádek. Pak stránka nového zařízení přestane nabízet Ano.
- **Cookie nového zařízení**: server vždy vygeneruje novou náhodnou
  hodnotu (nikdy nepřevezme existující), jméno s prefixem `__Host-`,
  `Secure`, `HttpOnly`, `SameSite=Lax`.
- **Zahlcení kódy** (nepřihlášený může vytvářet kódy, překlep oběti by mohl
  trefit útočníkův kód): globální strop platných `pending` záznamů (500 —
  nad ním „zkus to za chvíli“), limit na IP (IPv6 podle /64) 30 / hod,
  omezený počet pokusů o unikátní kód. Pravděpodobnost, že překlep trefí
  cizí kód, je pak ≤ 0,15 %.
- **Potvrzovací obrazovka** místo surové IP ukáže „Stejná síť jako ty:
  ano / ne“ (porovnání IP schvalujícího a nového zařízení), systém +
  prohlížeč a stáří kódu. User-Agent je jen
  orientační (útočník ho ovládá).
- **Limit neúspěchů**: nejdřív zapsat neúspěch, pak počítat (žádný souběh).
- **Devise**: před `approved → done` zkontrolovat
  `user.active_for_authentication?` (zamčený / nepotvrzený účet → hláška
  na novém zařízení).
- **Stavový endpoint**: záznam jen podle cookie (žádné id v URL), jméno
  uživatele vrací až ve stavu `approved`, `Cache-Control: no-store`.
- **IP za proxy**: ověřit při nasazení, že `request.ip` vrací IP klienta
  (nginx na stejném stroji → Rails důvěřuje loopbacku).

## Na stavitele

- Přesný vzhled stránek (Bootstrap 3 / ace jako zbytek tepu).
- Texty hlášek.

## Stav

Implementováno (commity dc2b962..HEAD na master); migrace 041 vyžaduje `make prod-migrate`.

## Úpravy po prvním vyzkoušení (rozhodnuto s uživatelem)

Tyto body mají přednost před starším textem výše.

1. **Obrázky podle písmen.** Pool je 22 obrázků, každý začíná jiným
   písmenem (bez Q, W, X, Y a bez háčků), v abecedním pořadí, index =
   pořadí v tabulce:
   A 🚗 auto, B 🍌 banán, C 🍋 citron, D 🐬 delfín, E 💶 euro, F 📷 foťák,
   G 🦍 gorila, H 🍄 houba, I 💉 injekce, J 🍎 jablko, K 🔑 klíč, L 🦁 lev,
   M 🍉 meloun, N 📰 noviny, O 🔥 oheň, P 🍕 pizza, R 🚀 raketa, S 🐘 slon,
   T 🐧 tučňák, U 🛸 ufo, V 🐝 včela, Z 🦓 zebra.
   U každého obrázku se ukazuje i velké písmeno. Na klávesnici přihlášené
   strany jde kód psát i písmeny z fyzické klávesnice (malá i velká,
   Backspace maže). 22⁴ ≈ 234 000 kódů; strop 500 → překlep trefí cizí kód
   s pravděpodobností ≤ 0,2 %.
2. **Po zadání kódu zmizí klávesnice.**
   - Nové zařízení ve **stejné síti** (`same_network?`): kód se rovnou
     schválí (`approve!`), přihlášená strana ukáže „Potvrďte přihlášení na
     novém zařízení (<systém · prohlížeč>)“ a tlačítko Zrušit (zruší
     `approved` záznam, nové zařízení pak dostane `cancelled`).
   - **Jiná síť**: zůstává panel s popisem zařízení, „Stejná síť jako ty:
     ne“, varováním a Potvrdit / Zrušit (ochrana proti phishingu); po
     Potvrdit totéž „Potvrďte přihlášení na novém zařízení“ + Zrušit.
   - Přihlášená strana se dotazuje stavu záznamu (jen svého, podle session
     id z `kod`) a po `done` ukáže „Hotovo, zařízení je přihlášené“, po
     `cancelled`/vypršení odpovídající hlášku.
3. **Odkaz a QR na přihlášené straně.** Stránka „Přihlásit na jiném
   zařízení“ ukáže absolutní URL `/prihlasit-zarizenim` a QR kód téhož
   odkazu (bez tajemství). QR jako SVG na serveru gemem `rqrcode`
   (schválená nová závislost).
