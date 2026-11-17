# Skenování řešení fotoaparátem

## Proč

Řešitelé fotí řešení mobilem. Dnes musí vyfotit stránky, najít je v galerii
a vybrat všechny najednou (fotoaparát z pole pro soubor vrací vždy jen jednu
fotku a každé nahrání přepíše předchozí). Fotky navíc přijdou nezpracované:
šikmé, se stínem, velké. Cíl: u úlohy tlačítko fotoaparátu, živě zvýrazněný
list A4, sken jedné stránky po druhé, úprava pro čitelnost a odeslání všech
stránek najednou.

## Cíle, ne-cíle, anti-cíle

- Cíl: kvalitní čitelný sken ručně psaného A4 (hlavní měřítko — rozhodl Vít).
- Cíl: víc stránek v jednom skenování, odeslání najednou.
- Ne-cíl: přidávání stránek k už nahranému řešení, mazání jednotlivých
  stránek na serveru (rozhodnuto: API se nemění, nové odeslání řešení
  nahradí jako dnes).
- Ne-cíl: OCR, rozpoznávání textu, nativní aplikace.
- Anti-cíl: zpomalit tep pro všechny — knihovna se načítá jen na vyžádání.
- Anti-cíl: skenování, které „nejde“ — když detekce listu selže, musí jít
  vždy použít celý snímek nebo rohy posunout ručně.

## Postupy (zvažované)

- **A) OpenCV.js uložené v tepu + vlastní kód — vybráno** (Vít: jde o
  kvalitu, 8 MB nevadí při líném načtení; volba knihovny na Claudovi).
  Plná kontrola nad detekcí i úpravami, jedna závislost.
- B) jscanify nad OpenCV.js — méně kódu, ale uvnitř totéž jednodušeji,
  úpravy obrazu stejně vlastní, další malá závislost s jedním autorem.
- C) Bez OpenCV, vlastní detekce hran v canvasu — lehké, ale na neklidném
  pozadí výrazně horší detekce.
- D) Nativní fotoaparát (`capture`) + úpravy na serveru — bez živé detekce,
  jedna fotka na nahrání; nesplňuje požadavek.

## Uživatelský průběh

1. Na stránce „Moje řešení“ (`app/views/sosna/solution/user_index.html.erb`)
   vedle tlačítka „<“ u každé úlohy tlačítko s ikonou fotoaparátu
   (tooltip „Skenovat fotoaparátem“). Ukazuje se jen tam, kde je dnes
   formulář pro nahrání, a jen když prohlížeč umí
   `navigator.mediaDevices.getUserMedia` (jinak se nezobrazí).
2. Klik otevře modal „Skenovat řešení: <název úlohy>“ se stavem „Připravuji
   skener…“. Načte se OpenCV.js (jednou za stránku), pak se požádá o kameru
   (zadní: `facingMode: environment`, co nejvyšší rozlišení, ideálně
   3840×2160).
3. Odmítnutý přístup / žádná kamera → srozumitelná hláška v modalu
   („Bez přístupu ke kameře skenovat nejde. Povol kameru v prohlížeči,
   nebo nahraj fotky tlačítkem vedle.“).
4. Živý náhled: zhruba 5× za sekundu se v menší kopii snímku hledá list a
   jeho obrys se kreslí přes video (zeleně, když je nalezen stabilně).
5. „Skenovat“ (v řádku „← Zrušit / 📷 Skenovat / ⬆ Odeslat“ pod kamerou,
   nad miniaturami) → snímek v plném rozlišení → zpracování (níže) →
   náhled výsledku s rohy, které jde tažením doladit, a tlačítky „Použít“ /
   „Znovu“. Po „Použít“ přibude dole miniatura stránky (s ✕ pro smazání).
6. „Odeslat“ → stránky jako JPEG `Úloha 2.jpg`, `Úloha 2 – strana 2.jpg`, …
   (server pojmenuje PDF podle první: `Úloha 2.pdf`)
   přes stávající upload (víc obrázků → PDF na serveru, nahradí dosavadní
   řešení). Po odeslání se stránka obnoví (zobrazí se flash ze serveru).
   „Zrušit“ zavře modal, zastaví kameru a zahodí stránky.
7. Zavření modalu vždy zastaví kameru (stopnout všechny tracky).

## Zpracování snímku

1. **Detekce listu**: šedá → rozmazání → Canny → dilatace → obrysy →
   aproximace polygonem; vybrat největší konvexní čtyřúhelník s plochou
   ≥ 20 % snímku. Rohy seřadit (vlevo nahoře, vpravo nahoře, vpravo dole,
   vlevo dole). Nenalezen → rohy = celý snímek.
2. **Vyrovnání perspektivy** na výšku A4 při **150 dpi = 1240 × 1754 px**
   (širší strana čtyřúhelníku → orientace: list naležato se otočí na výšku).
3. **Odstranění stínu / vybělení**: šedá, pozadí = silně rozmazaná (nebo
   morfologicky uzavřená) kopie, výsledek = obraz / pozadí × 255.
4. **Kontrast**: mírné roztažení histogramu (bílá papíru → 255, inkoust
   tmavý), **ne** tvrdá černobílá (zachová slabou tužku a šrafy).
5. **Výstup**: JPEG ve stupních šedi, kvalita 0,85 (odhad 120–200 kB na
   stránku). 150 dpi rozhodnuto: snímek z videa nese ~155 dpi skutečných
   detailů, víc by soubor jen nafouklo.

Parametry (prahy Canny, velikost rozmazání pozadí, roztažení) jsou na
staviteli; měřítkem je čitelnost tužky a pera na testovacích fotkách.

## Technika

- OpenCV.js 4.x (oficiální build `opencv.js`, Apache 2.0) jako
  `public/javascripts/opencv-<verze>.js` — **není v gitu** (`.gitignore`),
  stahuje ho `make opencv` (jen když chybí, ověří SHA-256); `make release`
  na serveru spouští `pull restart opencv`. Prohlížeč ho načítá z tepu
  (žádné CDN) dynamicky `<script>` až při prvním otevření skeneru; verze v
  názvu → cachovatelné natrvalo (při nasazení ověřit cache hlavičky Apache
  pro `/javascripts/`). Testy (`make test-js`) potřebují soubor stažený.
- OpenCV.js verze 4.13.0 (`https://docs.opencv.org/4.13.0/opencv.js`),
  inicializace přes `cv.onRuntimeInitialized`.
- Kód skeneru v samostatném `public/javascripts/scanner.js` (UMD: v
  prohlížeči `window.TepScanner`, v Node `module.exports`): čisté funkce nad
  `cv.Mat` (detekce rohů, seřazení, vyrovnání, úpravy) bez canvasu a bez
  kódování JPEG; UI (modal, kamera, miniatury, kódování JPEG přes canvas,
  odeslání) navázané z `tep.js`.
- Odeslání: stránky jako `File` objekty vložené přes `DataTransfer` do
  stávajícího file inputu formuláře dané úlohy a normální `submit()`
  formuláře (PATCH přes `_method`, CSRF z formuláře). Prohlížeč pak sám
  projde přesměrováním a flash hláška se zobrazí jako dnes (fetch by flash
  spotřeboval při sledování přesměrování). Nikdy neodesílat 0 stránek
  (prázdný upload na serveru řešení smaže).
- Server beze změny (upload, max velikost 20 MB na soubor, složení do PDF
  Prawnem; obrázek se vejde do okrajů 36 pt → efektivně ~227 dpi, stačí).
- Modal je jen ve view `user_index` (ne v layoutu), tlačítko je ve stejné
  větvi jako formulář (i pro `show_nahrat_admin`, ne u úloh jen pro mladší).
- Kamera: video ideálně 3840×2160, fallback na cokoli dostupného. Snímek
  pro sken přes `ImageCapture.takePhoto()` (plný snímač, Chrome/Android),
  kde není, snímek z videa. Maty po zpracování uvolňovat; stránky držet
  jako JPEG bloby; strop 20 stránek.
- Kamera vyžaduje HTTPS (produkce: Apache) nebo localhost (vývoj).
- Bez nových gemů.

## Testy

- **Node testy zpracování** (`test/js/scanner_test.js`, `node:test`,
  cíl `make test-js`, bez npm závislostí): OpenCV.js načtené v Node,
  `scanner.js` přes `require`; testovací obrázky se generují v testu přímo
  OpenCV (kreslení polygonu, textu, gradientu stínu) — několik
  syntetických (bílý list s textem na barevném/strukturovaném pozadí,
  perspektivně zkosený, se stínem, naležato) se známými rohy:
  detekované rohy do tolerance (např. 2 % rozměru), rozměr výstupu
  1240×1754, list naležato → výstup na výšku, papír po vybělení světlý
  (medián > 230) i ve stínu, text zůstane tmavý; nenalezený list → celý
  snímek.
- **Rails test**: u úlohy s formulářem pro nahrání je tlačítko skeneru
  s potřebnými daty (url uploadu, id řešení, název úlohy).
- **Vizuální kontrola** v headless Chromiu s podvrženou kamerou
  (`--use-fake-device-for-media-stream --use-file-for-fake-video-capture`)
  na šířce mobilu i počítače.

## Na stavitele

- Přesné parametry zpracování a vzhled modalu (Bootstrap 3 / ace).
- Zda detekce běží ve Web Workeru (pokud by živý náhled sekal).
- Texty hlášek.
