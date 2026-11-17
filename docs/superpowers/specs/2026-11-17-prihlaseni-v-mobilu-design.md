# Přihlášení pomocí jiného (už přihlášeného) zařízení

## Proč

Psát dlouhé heslo do mobilu je nepříjemné. Kdo je přihlášený v tepu na
jednom zařízení (počítač nebo mobil), má se na druhém přihlásit opsáním
4 ikon, bez hesla. Funguje stejně v obou směrech, bez QR a fotoaparátu.
Stejný princip jako přihlášení televize k Netflixu/YouTube.

## Cíle a ne-cíle

- Cíl: nové zařízení ukáže 4 ikony, uživatel je zadá na už přihlášeném
  zařízení a nové zařízení se přihlásí.
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

1. **Nové zařízení**: na přihlašovací stránce odkaz „Přihlásit pomocí
   jiného zařízení“ → `/prihlasit-zarizenim`. Vytvoří záznam a ukáže
   4 ikony s názvy (velké, dobře čitelné) a návod „Na zařízení, kde jsi
   v tepu přihlášený, otevři menu → Přihlásit jiné zařízení a zadej tyto
   ikony.“ Odpočet platnosti, „Nový kód“. Zaškrtávátko „Zůstat
   přihlášený“ — výchozí zapnuto pro mobilní prohlížeč, vypnuto pro
   počítač (sdílené počítače).
2. **Přihlášené zařízení**: v uživatelském menu (vedle Logout) „Přihlásit
   jiné zařízení“ → `/prihlasit-zarizeni`. Klávesnice 24 ikon (mřížka
   4×6, ikona + název), 4 pole, „Smazat“. Po 4. ikoně se odešle.
3. Server najde platný záznam ve stavu `pending` s tímto kódem.
   Nenalezen → „Kód neplatí nebo vypršel“, počítá se jako neúspěch do
   limitu. Nalezen → ukáže popis nového zařízení + Potvrdit / Zrušit.
4. **Potvrdit** → stav `approved`, `user_id` = přihlášený uživatel
   (atomicky `UPDATE … WHERE state = 'pending' AND expires_at > now`).
   Zrušit → `cancelled`.
5. **Nové zařízení** (dotaz po 2 s, identifikace httponly cookie, v DB
   jen SHA-256) při `approved` ukáže „Přihlásit jako <jméno>?“:
   Ano → `sign_in` (remember podle zaškrtávátka), stav `done`,
   přesměrování na titulní stránku. To nejsem já → `cancelled`.
   Byl-li prohlížeč přihlášený za někoho jiného, nejdřív odhlásit.

## Platnost a kódy

- Kód platí 5 minut od vytvoření (pokrývá přechod k druhému zařízení).
- Kód = 4 ikony z poolu 24, opakování povoleno; mezi platnými `pending`
  záznamy unikátní (při kolizi vylosovat znovu).
- Staré záznamy (> 1 den) se mažou při vytváření nového.
- Limit vytváření kódů: 20 / hod na IP.

## Data

Nová tabulka `device_logins`: `code` (string, 4 indexy do poolu, např.
`3-17-0-22`), `state` (`pending` / `approved` / `done` / `cancelled`),
`user_id` (při potvrzení), `device_digest` (SHA-256 cookie nového
zařízení), `user_agent`, `ip`, `remember` (bool), `expires_at`,
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
- Odkaz na přihlašovací stránce Devise (`app/views/devise/sessions/new`),
  položka v uživatelském menu v `app/views/layouts/application.html.erb`.
- Dotazování: jQuery, JSON endpoint, `setTimeout` 2 s; zastaví se po
  koncovém stavu nebo vypršení.
- Popis zařízení z User-Agent jednoduchým rozpoznáním (Android / iPhone /
  Windows / Mac / Linux + Chrome / Firefox / Safari / Edge), bez gemu.
- Testy (functional): celý průběh, neplatný/vypršelý kód, limit
  neúspěchů, zrušení na obou stranách, kód nejde použít znovu, cizí
  prohlížeč (jiná cookie) nedostane přihlášení, remember podle volby,
  unikátnost kódů mezi platnými.

## Na stavitele

- Přesný vzhled stránek (Bootstrap 3 / ace jako zbytek tepu).
- Texty hlášek.
