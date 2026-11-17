# Skenování řešení fotoaparátem — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tlačítko fotoaparátu u úlohy otevře skener: živá detekce listu A4, sken stránek s vyrovnáním a vylepšením na 150 dpi, odeslání všech stránek přes stávající upload.

**Architecture:** OpenCV.js 4.10.0 stažené `make opencv` (mimo git) a načtené až při otevření skeneru. Čisté zpracování obrazu v `public/javascripts/scanner.js` (UMD, testované v Node), UI (modal, kamera, miniatury, odeslání přes `DataTransfer` do stávajícího formuláře) v `tep.js` + markup ve view `user_index`. Server beze změny.

**Tech Stack:** Rails 7.2 (view + minitest), jQuery + Bootstrap 3 modal, OpenCV.js 4.10.0, Node 22 `node:test`, headless Chromium s podvrženou kamerou.

**Spec:** `docs/superpowers/specs/2026-11-17-skenovani-reseni-design.md`

## Global Constraints

- OpenCV.js 4.10.0 z `https://docs.opencv.org/4.10.0/opencv.js` → `public/javascripts/opencv-4.10.0.js`, v `.gitignore`, ověřený SHA-256.
- Výstup stránky: A4 na výšku **1240 × 1754 px** (150 dpi), JPEG stupně šedi kvalita 0,85.
- Nejvýš 20 stránek; nikdy neodeslat 0 stránek. Soubory `strana-1.jpg … strana-N.jpg`.
- Server (`Sosna::SolutionController#upload`) se nemění.
- Tlačítko jen tam, kde je dnes formulář pro nahrání (stejná větev ve view), jen když prohlížeč má `navigator.mediaDevices.getUserMedia`.
- Komentáře ≤ 1 řádek, současný stav. Commity česky, bez Co-Authored-By, na master. Žádné nové gemy ani npm závislosti. Vít klade důraz na testy.

## Review Focus

1. Odmítnutá kamera / žádná kamera / OpenCV se nenačte → srozumitelná hláška v modalu, žádná výjimka, tlačítko „Odeslat“ neaktivní.
2. Zavření modalu (✕, Esc, Zrušit, odeslání) vždy zastaví kameru (všechny tracky) a uvolní Maty.
3. List nenalezen nebo nalezený nesmysl (malý / nekonvexní čtyřúhelník) → použije se celý snímek; ruční rohy nesmí jít mimo obrázek.
4. List naležato nebo vzhůru nohama v záběru → výstup vždy na výšku 1240×1754 (natočení podle delší strany; obrácení vzhůru nohama se neřeší).
5. Formulář úlohy se při odeslání neplete s jinou úlohou na stránce (každé tlačítko nese id svého formuláře).

---

### Task 1: `make opencv` a nasazení

**Files:** `Makefile`, `.gitignore`.

- [ ] Cíl `opencv`: když `public/javascripts/opencv-4.10.0.js` chybí, stáhne ho (`curl -fsSL`) do dočasného souboru, ověří SHA-256 (hodnotu zjistit jedním stažením teď a zapsat do Makefile jako proměnnou), přesune na místo; když existuje, jen ověří hash (nesouhlas → chyba). Idempotentní.
- [ ] `release`: na serveru `make -C rails/tep pull opencv restart`.
- [ ] `.gitignore`: `/public/javascripts/opencv-*.js`.
- [ ] Ověřit: `make opencv` dvakrát po sobě (podruhé nic nestahuje), poškozený soubor → chyba. Soubor nesmí být ve `git status`.
- [ ] Commit `skenování: make opencv stáhne a ověří OpenCV.js 4.10.0, release ho spouští na serveru`.

### Task 2: Zpracování obrazu `scanner.js` + Node testy

**Files:** `public/javascripts/scanner.js`, `test/js/scanner_test.js`, `Makefile` (cíl `test-js`).

**Interfaces** (`TepScanner` v prohlížeči / `module.exports` v Node; všechny funkce dostávají `cv` jako první argument, vstupní Maty RGBA nevlastní a neuvolňují):
- `PAGE_W = 1240`, `PAGE_H = 1754`.
- `findSheet(cv, rgba) -> [[x,y]×4] | null` — rohy listu v pořadí vlevo-nahoře, vpravo-nahoře, vpravo-dole, vlevo-dole; null když není čtyřúhelník s plochou ≥ 20 % snímku. Interně pracuje na zmenšené kopii (delší strana ~800 px) a rohy přepočte.
- `orderCorners(points) -> [[x,y]×4]`.
- `fullFrame(w, h) -> [[x,y]×4]`.
- `clampCorners(corners, w, h) -> corners` (do obrázku).
- `warpToPage(cv, rgba, corners) -> cv.Mat` (šedá 1240×1754; když je čtyřúhelník širší než vyšší, výstup otočený na výšku).
- `enhance(cv, gray) -> cv.Mat` (odstranění stínu dělením rozmazaným pozadím, roztažení kontrastu; bez tvrdé binarizace).
- `scanPage(cv, rgba, corners|null) -> cv.Mat` = warp + enhance (null → `findSheet` → jinak `fullFrame`).

Testy (`node --test test/js/scanner_test.js`; OpenCV načtené `require` souboru `public/javascripts/opencv-4.10.0.js`, čekat na `onRuntimeInitialized`; obrázky generované v testu kreslením do `cv.Mat`):
- [ ] `orderCorners` pro zamíchané body vrátí správné pořadí; `clampCorners` ořízne do obrázku.
- [ ] Syntetický snímek 1920×1080: šedohnědé texturované pozadí, bílý čtyřúhelník (list) se známými rohy, perspektivně zkosený, s tmavými čarami „textu“ → `findSheet` vrátí rohy do 2 % delšího rozměru.
- [ ] Malý bílý obdélník (< 20 % plochy) nebo prázdný snímek → `findSheet` null; `scanPage(…, null)` pak použije celý snímek (rozměr výstupu 1240×1754).
- [ ] `warpToPage` → 1240×1754, 1 kanál; list naležato (širší než vyšší) → výstup taky 1240×1754 a „text“ otočený (ověřit polohu tmavého značkovacího bodu v rohu listu).
- [ ] `enhance` na listu se stínem (lineární gradient jasu 255→140 přes list): medián papíru ve stinné i světlé polovině > 230; tmavé čáry textu zůstanou < 100.
- [ ] Žádné úniky: počet živých Matů není potřeba měřit, ale každá funkce uvolní své dočasné Maty (code review).
- [ ] `make test-js` (závisí na `opencv`) spouští testy. Commit `skenování: zpracování obrazu (detekce listu, vyrovnání, vybělení) s Node testy`.

### Task 3: Skener v UI

**Files:** `app/views/sosna/solution/user_index.html.erb`, `public/javascripts/tep.js`, `app/views/layouts/application.html.erb` (`tep.js?v=` +1), `test/functional/` (nový nebo existující test pro `user_index`).

**Interfaces:**
- Tlačítko vedle „<“ v té samé větvi jako formulář: `<button type="button" class="btn btn-default solution-scan hide" title="Skenovat fotoaparátem" data-form="#<id formuláře>" data-title="<název úlohy>" data-opencv="/javascripts/opencv-4.10.0.js" data-scanner="/javascripts/scanner.js?v=…"><i class="fa fa-camera"></i></button>`; JS ho odkryje jen když `navigator.mediaDevices && navigator.mediaDevices.getUserMedia`.
- Jeden modal `#solution-scan-modal` ve view `user_index` (mimo smyčku).
- `init_solution_scan()` v tep.js (navázané v document ready): líné načtení `opencv` a `scanner.js` (jednou za stránku, Promise), stav „Připravuji skener…“, `getUserMedia({video:{facingMode:'environment', width:{ideal:3840}, height:{ideal:2160}}})`, video + overlay canvas s obrysem listu (detekce ~5× za s na zmenšeném snímku), tlačítko „Skenovat stránku“ (snímek přes `ImageCapture.takePhoto()` když existuje, jinak z videa) → náhled výsledku s přetahovatelnými rohy (myš i dotyk) a Použít / Znovu → miniatury s ✕ → „Odeslat N stránek“ (neaktivní při 0, strop 20) → `File`y do `DataTransfer`, nastavit `files` file inputu formuláře z `data-form`, `form.submit()`. Zavření modalu zastaví kameru.
- Texty: „Skenovat řešení: <úloha>“, „Připravuji skener…“, „Bez přístupu ke kameře skenovat nejde. Povol kameru v prohlížeči, nebo nahraj fotky tlačítkem vedle.“, „Skenovat stránku“, „Použít“, „Znovu“, „Odeslat N stránek“, „Zrušit“, „List nenalezen – použije se celý snímek, rohy můžeš posunout.“, „Víc než 20 stránek odeslat nejde.“

- [ ] Rails test: přihlášený řešitel na `user_index` v otevřeném kole vidí u úlohy s formulářem tlačítko `.solution-scan` s `data-form` ukazujícím na existující formulář té úlohy; u úlohy jen pro mladší (pro nejuniora) tlačítko není; modal je na stránce právě jednou.
- [ ] Vizuální kontrola v headless Chromiu s `--use-fake-ui-for-media-stream --use-fake-device-for-media-stream --use-file-for-fake-video-capture=<y4m/mjpeg fotka listu na stole>` (harness ve scratchpadu, view markup ručně zkopírovaný): modal po načtení, obrys listu, náhled skenu, miniatury, na 380 i 1100 px. Ověřit DOM dumpem, že po „Odeslat“ má file input N souborů `strana-*.jpg` a formulář by se odeslal (submit zachytit).
- [ ] Odmítnutá kamera (bez fake-ui flagu) → hláška; zavření modalu → `track.readyState === 'ended'`.
- [ ] Full suite + `make test-js`. Commit `skenování: tlačítko fotoaparátu a skener v modalu; tep.js?v=…`.
