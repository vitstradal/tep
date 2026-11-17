'use strict';

const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const S = require('../../public/javascripts/scanner.js');
const OPENCV_JS = path.join(__dirname, '../../public/javascripts/opencv-4.13.0.js');

let cv;

// Emscripten module je thenable: resolve(cv) by ho rozbaloval donekonečna, proto obal.
function loadOpenCv() {
  return new Promise((resolve) => {
    const m = require(OPENCV_JS);
    if (typeof m.then === 'function') m.then((ready) => resolve({ cv: ready }));
    else if (m.Mat) resolve({ cv: m });
    else m.onRuntimeInitialized = () => resolve({ cv: m });
  });
}

before(async () => { cv = (await loadOpenCv()).cv; });

const FRAME_W = 1920;
const FRAME_H = 1080;
const PAPER = 245;
const INK = 30;
const PENCIL = 185;
const MARK = { x: 110, y: 110, r: 45 };
const TEXT_ROWS = [];
for (let y = 300; y < 1600; y += 80) TEXT_ROWS.push(y);
const TEXT_X0 = 200;
const TEXT_X1 = 1040;
const PENCIL_ROWS = [340, 660, 980, 1300];

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function withMats(fn) {
  const mats = [];
  const track = (m) => { mats.push(m); return m; };
  try { return fn(track); } finally { mats.forEach((m) => { if (!m.isDeleted()) m.delete(); }); }
}

// Šedá stránka 1240×1754: papír, řádky „textu“ perem, slabé čáry tužkou, značka vlevo nahoře.
function makePage() {
  const page = new cv.Mat(S.PAGE_H, S.PAGE_W, cv.CV_8UC1, new cv.Scalar(PAPER));
  for (const y of TEXT_ROWS) {
    cv.line(page, new cv.Point(TEXT_X0, y), new cv.Point(TEXT_X1, y), new cv.Scalar(INK), 4);
  }
  for (const y of PENCIL_ROWS) {
    cv.line(page, new cv.Point(TEXT_X0, y), new cv.Point(TEXT_X1, y), new cv.Scalar(PENCIL), 2);
  }
  cv.circle(page, new cv.Point(MARK.x, MARK.y), MARK.r, new cv.Scalar(0), -1);
  return page;
}

function grayToRgba(gray) {
  const rgba = new cv.Mat();
  cv.cvtColor(gray, rgba, cv.COLOR_GRAY2RGBA);
  return rgba;
}

// Šedohnědé „dřevo“: šum + vodorovná léta, deterministické.
function texturedBackground(w, h, seed = 1) {
  const bg = new cv.Mat(h, w, cv.CV_8UC4);
  const rand = rng(seed);
  const grain = [];
  for (let y = 0; y < h; y++) grain.push(Math.sin(y / 7) * 12 + Math.sin(y / 31) * 10);
  const d = bg.data;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const n = (rand() - 0.5) * 50 + grain[y];
      const i = (y * w + x) * 4;
      d[i] = 125 + n;
      d[i + 1] = 108 + n;
      d[i + 2] = 92 + n;
      d[i + 3] = 255;
    }
  }
  cv.GaussianBlur(bg, bg, new cv.Size(3, 3), 0);
  return bg;
}

function quadMat(points) {
  return cv.matFromArray(4, 1, cv.CV_32FC2, points.flat());
}

// Vloží stránku (RGBA) do snímku tak, aby její rohy TL, TR, BR, BL padly na `corners`.
function placePage(frame, pageRgba, corners) {
  withMats((t) => {
    const src = t(quadMat([[0, 0], [pageRgba.cols, 0], [pageRgba.cols, pageRgba.rows], [0, pageRgba.rows]]));
    const dst = t(quadMat(corners));
    const m = t(cv.getPerspectiveTransform(src, dst));
    const warped = t(new cv.Mat());
    cv.warpPerspective(pageRgba, warped, m, new cv.Size(frame.cols, frame.rows));
    const ones = t(new cv.Mat(pageRgba.rows, pageRgba.cols, cv.CV_8UC1, new cv.Scalar(255)));
    const mask = t(new cv.Mat());
    cv.warpPerspective(ones, mask, m, new cv.Size(frame.cols, frame.rows), cv.INTER_NEAREST);
    warped.copyTo(frame, mask);
  });
}

function frameWithPage(corners, { rotateCcw = false, seed = 1 } = {}) {
  return withMats((t) => {
    const frame = texturedBackground(FRAME_W, FRAME_H, seed);
    let page = t(makePage());
    if (rotateCcw) {
      const r = t(new cv.Mat());
      cv.rotate(page, r, cv.ROTATE_90_COUNTERCLOCKWISE);
      page = r;
    }
    placePage(frame, t(grayToRgba(page)), corners);
    return frame;
  });
}

function regionMean(gray, x, y, w, h) {
  const roi = gray.roi(new cv.Rect(x, y, w, h));
  const m = cv.mean(roi)[0];
  roi.delete();
  return m;
}

function regionMedian(gray, x, y, w, h) {
  const roi = gray.roi(new cv.Rect(x, y, w, h));
  const hist = new Array(256).fill(0);
  for (let r = 0; r < roi.rows; r++) for (let c = 0; c < roi.cols; c++) hist[roi.ucharAt(r, c)]++;
  roi.delete();
  let acc = 0;
  const half = (w * h) / 2;
  for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc >= half) return v; }
  return 255;
}

function assertCornersNear(actual, expected, tolerance) {
  assert.ok(actual, 'list nenalezen');
  assert.equal(actual.length, 4);
  actual.forEach((p, i) => {
    const d = Math.hypot(p[0] - expected[i][0], p[1] - expected[i][1]);
    assert.ok(d <= tolerance, `roh ${i}: ${p} místo ${expected[i]} (odchylka ${d.toFixed(1)} > ${tolerance})`);
  });
}

function assertPage(mat) {
  assert.equal(mat.cols, S.PAGE_W);
  assert.equal(mat.rows, S.PAGE_H);
  assert.equal(mat.channels(), 1);
  assert.equal(mat.type(), cv.CV_8UC1);
}

const TOL = 0.02 * FRAME_W;
const SKEWED = [[640, 70], [1330, 140], [1400, 1010], [540, 960]];

test('konstanty rozměru stránky', () => {
  assert.equal(S.PAGE_W, 1240);
  assert.equal(S.PAGE_H, 1754);
});

test('orderCorners seřadí každou permutaci rohů', () => {
  const ordered = [[100, 50], [900, 80], [950, 700], [60, 640]];
  const perms = (a) => (a.length <= 1 ? [a] : a.flatMap((x, i) => perms([...a.slice(0, i), ...a.slice(i + 1)]).map((p) => [x, ...p])));
  for (const p of perms(ordered)) assert.deepEqual(S.orderCorners(p), ordered);
});

test('orderCorners zvládne list pootočený o 30°', () => {
  const cx = 500, cy = 500, a = Math.PI / 6;
  const rot = ([x, y]) => [cx + (x - cx) * Math.cos(a) - (y - cy) * Math.sin(a), cy + (x - cx) * Math.sin(a) + (y - cy) * Math.cos(a)];
  const ordered = [[300, 200], [700, 200], [700, 800], [300, 800]].map(rot);
  assert.deepEqual(S.orderCorners([ordered[2], ordered[0], ordered[3], ordered[1]]), ordered);
});

test('fullFrame vrátí rohy celého obrázku', () => {
  assert.deepEqual(S.fullFrame(1920, 1080), [[0, 0], [1919, 0], [1919, 1079], [0, 1079]]);
});

test('clampCorners ořízne rohy do obrázku a nezmění vstup', () => {
  const input = [[-5, -3], [2000, 10], [1950, 1200], [-1, 1100]];
  assert.deepEqual(S.clampCorners(input, 1920, 1080), [[0, 0], [1919, 10], [1919, 1079], [0, 1079]]);
  assert.deepEqual(input[0], [-5, -3]);
  assert.deepEqual(S.clampCorners([[10, 20], [30, 40], [50, 60], [70, 80]], 1920, 1080), [[10, 20], [30, 40], [50, 60], [70, 80]]);
});

test('findSheet najde perspektivně zkosený list na texturovaném pozadí', () => {
  withMats((t) => {
    const frame = t(frameWithPage(SKEWED));
    assertCornersNear(S.findSheet(cv, frame), SKEWED, TOL);
    assert.equal(frame.cols, FRAME_W, 'vstup zůstal nedotčený');
  });
});

test('findSheet najde list pootočený a blízko okraje snímku', () => {
  const corners = [[300, 120], [1150, 30], [1260, 1050], [420, 1060]];
  withMats((t) => {
    assertCornersNear(S.findSheet(cv, t(frameWithPage(corners, { seed: 7 }))), corners, TOL);
  });
});

test('findSheet najde list naležato', () => {
  const corners = [[260, 160], [1700, 120], [1660, 1000], [300, 1040]];
  withMats((t) => {
    assertCornersNear(S.findSheet(cv, t(frameWithPage(corners, { rotateCcw: true, seed: 3 }))), corners, TOL);
  });
});

test('findSheet najde list na světlém stole se stínem', () => {
  const corners = [[600, 100], [1300, 100], [1300, 1000], [600, 1000]];
  withMats((t) => {
    const frame = t(new cv.Mat(FRAME_H, FRAME_W, cv.CV_8UC4, new cv.Scalar(200, 195, 185, 255)));
    placePage(frame, t(grayToRgba(t(makePage()))), corners);
    const d = frame.data;
    for (let y = 0; y < FRAME_H; y++) {
      for (let x = 0; x < FRAME_W; x++) {
        const f = 1 - 0.4 * (x / FRAME_W);
        const i = (y * FRAME_W + x) * 4;
        d[i] *= f; d[i + 1] *= f; d[i + 2] *= f;
      }
    }
    assertCornersNear(S.findSheet(cv, frame), corners, TOL);
  });
});

test('findSheet najde rozostřený list s malým kontrastem vůči stolu', () => {
  const corners = [[560, 90], [1360, 110], [1380, 1000], [540, 980]];
  withMats((t) => {
    const frame = t(new cv.Mat(FRAME_H, FRAME_W, cv.CV_8UC4, new cv.Scalar(175, 170, 160, 255)));
    const page = t(makePage());
    page.data.forEach((v, i) => { page.data[i] = Math.round(v * 0.85); });
    placePage(frame, t(grayToRgba(page)), corners);
    cv.GaussianBlur(frame, frame, new cv.Size(31, 31), 0);
    assertCornersNear(S.findSheet(cv, frame), corners, TOL);
  });
});

test('findSheet vrátí null pro malý list (< 20 % snímku)', () => {
  const corners = [[800, 300], [1100, 300], [1100, 700], [800, 700]];
  withMats((t) => {
    assert.equal(S.findSheet(cv, t(frameWithPage(corners))), null);
  });
});

test('findSheet vrátí null pro prázdný a pro jen texturovaný snímek', () => {
  withMats((t) => {
    assert.equal(S.findSheet(cv, t(new cv.Mat(FRAME_H, FRAME_W, cv.CV_8UC4, new cv.Scalar(128, 128, 128, 255)))), null);
    assert.equal(S.findSheet(cv, t(texturedBackground(FRAME_W, FRAME_H, 5))), null);
  });
});

test('scanPage bez rohů a bez nalezeného listu zpracuje celý snímek', () => {
  withMats((t) => {
    const frame = t(frameWithPage([[800, 300], [1100, 300], [1100, 700], [800, 700]]));
    const out = t(S.scanPage(cv, frame, null));
    assertPage(out);
  });
});

test('scanPage bez rohů list sám najde, vyrovná a vybělí', () => {
  withMats((t) => {
    const out = t(S.scanPage(cv, t(frameWithPage(SKEWED)), null));
    assertPage(out);
    assert.ok(regionMean(out, MARK.x - 20, MARK.y - 20, 40, 40) < 60, 'značka vlevo nahoře');
    assert.ok(regionMedian(out, 1100, 200, 100, 1400) > 230, 'papír vpravo bílý');
    assert.ok(regionMedian(out, 60, 300, 100, 1400) > 230, 'papír vlevo bílý');
    const edges = {
      nahoře: regionMean(out, 0, 0, S.PAGE_W, 3),
      dole: regionMean(out, 0, S.PAGE_H - 3, S.PAGE_W, 3),
      vlevo: regionMean(out, 0, 0, 3, S.PAGE_H),
      vpravo: regionMean(out, S.PAGE_W - 3, 0, 3, S.PAGE_H),
    };
    for (const [side, m] of Object.entries(edges)) assert.ok(m > 240, `okraj ${side} bez pruhu pozadí (${m.toFixed(1)})`);
  });
});

test('scanPage se zadanými rohy je použije', () => {
  withMats((t) => {
    const frame = t(frameWithPage(SKEWED));
    const out = t(S.scanPage(cv, frame, SKEWED));
    assertPage(out);
    assert.ok(regionMean(out, MARK.x - 20, MARK.y - 20, 40, 40) < 60);
  });
});

test('warpToPage vyrovná list na 1240×1754 šedou stránku', () => {
  withMats((t) => {
    const frame = t(frameWithPage(SKEWED));
    const out = t(S.warpToPage(cv, frame, SKEWED));
    assertPage(out);
    assert.ok(regionMean(out, MARK.x - 20, MARK.y - 20, 40, 40) < 60, 'značka vlevo nahoře');
    assert.ok(regionMean(out, S.PAGE_W - 150, 50, 100, 100) > 200, 'vpravo nahoře papír');
    assert.ok(regionMean(out, 50, S.PAGE_H - 150, 100, 100) > 200, 'vlevo dole papír');
    assert.ok(regionMean(out, TEXT_X0 + 100, TEXT_ROWS[3] - 1, 600, 3) < 100, 'řádek textu je na svém místě');
    assert.ok(regionMean(out, TEXT_X0 + 100, TEXT_ROWS[3] + 30, 600, 10) > 200, 'mezi řádky papír');
    assert.equal(frame.channels(), 4, 'vstup zůstal nedotčený');
  });
});

test('warpToPage otočí list naležato na výšku', () => {
  const corners = [[260, 160], [1700, 120], [1660, 1000], [300, 1040]];
  withMats((t) => {
    const out = t(S.warpToPage(cv, t(frameWithPage(corners, { rotateCcw: true })), corners));
    assertPage(out);
    assert.ok(regionMean(out, MARK.x - 20, MARK.y - 20, 40, 40) < 60, 'značka vlevo nahoře');
    for (const [x, y] of [[S.PAGE_W - 150, 50], [S.PAGE_W - 150, S.PAGE_H - 150], [50, S.PAGE_H - 150]]) {
      assert.ok(regionMean(out, x, y, 100, 100) > 200, `roh ${x},${y} je papír`);
    }
    assert.ok(regionMean(out, TEXT_X0 + 100, TEXT_ROWS[3] - 1, 600, 3) < 100, 'řádky textu vodorovně');
  });
});

test('warpToPage s rohy v libovolném pořadí dá stejný výsledek', () => {
  withMats((t) => {
    const frame = t(frameWithPage(SKEWED));
    const out = t(S.warpToPage(cv, frame, [SKEWED[2], SKEWED[0], SKEWED[3], SKEWED[1]]));
    assert.ok(regionMean(out, MARK.x - 20, MARK.y - 20, 40, 40) < 60);
  });
});

test('warpToPage zmenší velký snímek bez ztráty tenkých čar', () => {
  const corners = [[300, 200], [2700, 200], [2700, 3600], [300, 3600]];
  const lines = [];
  for (let y = 400; y < 3200; y += 13) lines.push(y);
  withMats((t) => {
    const frame = t(new cv.Mat(3800, 3000, cv.CV_8UC4, new cv.Scalar(120, 110, 100, 255)));
    const page = t(new cv.Mat(3400, 2400, cv.CV_8UC1, new cv.Scalar(PAPER)));
    for (const y of lines) cv.line(page, new cv.Point(200, y), new cv.Point(2200, y), new cv.Scalar(60), 1);
    placePage(frame, t(grayToRgba(page)), corners);
    const out = t(S.warpToPage(cv, frame, corners));
    assertPage(out);
    for (const y of lines) {
      const y0 = Math.round((y * S.PAGE_H) / 3400);
      let min = 255;
      for (let r = y0 - 3; r <= y0 + 3; r++) min = Math.min(min, regionMean(out, 300, r, 600, 1));
      assert.ok(min < PAPER - 30, `čára ${y} viditelná (${min.toFixed(1)})`);
    }
  });
});

function shadedPage(t, noise = 0) {
  const page = t(makePage());
  const rand = rng(17);
  const d = page.data;
  for (let y = 0; y < page.rows; y++) {
    for (let x = 0; x < page.cols; x++) {
      const i = y * page.cols + x;
      const v = (d[i] * (255 - (115 * x) / (page.cols - 1))) / 255 + (rand() - 0.5) * noise;
      d[i] = Math.max(0, Math.min(255, Math.round(v)));
    }
  }
  return page;
}

const STRIPS = 8;
function stripMedians(gray) {
  const w = gray.cols / STRIPS;
  return Array.from({ length: STRIPS }, (_, i) => regionMedian(gray, Math.round(i * w), 0, Math.round(w), gray.rows));
}

test('enhance vybělí papír ve stínu i na světle a nechá text tmavý', () => {
  withMats((t) => {
    const page = shadedPage(t);
    const before = stripMedians(page);
    const out = t(S.enhance(cv, page));
    assertPage(out);
    assert.ok(before[STRIPS - 1] < 160, `vstup je ve stínu tmavý (${before})`);
    const medians = stripMedians(out);
    assert.ok(regionMedian(out, 0, 0, S.PAGE_W / 2, S.PAGE_H) > 230, 'světlá polovina bílá');
    assert.ok(regionMedian(out, S.PAGE_W / 2, 0, S.PAGE_W / 2, S.PAGE_H) > 230, 'stinná polovina bílá');
    medians.forEach((m, i) => assert.ok(m > 230, `papír v pruhu ${i} bílý: ${medians}`));
    for (const x of [TEXT_X0 + 50, (TEXT_X0 + TEXT_X1) / 2, TEXT_X1 - 50]) {
      for (const y of TEXT_ROWS) assert.ok(out.ucharAt(y, x) < 100, `text ${x},${y}: ${out.ucharAt(y, x)}`);
    }
    assert.deepEqual(stripMedians(page), before, 'vstup zůstal nedotčený');
  });
});

test('enhance udělá ze zašuměného papíru ve stínu čistou bílou', () => {
  withMats((t) => {
    const out = t(S.enhance(cv, shadedPage(t, 16)));
    const medians = stripMedians(out);
    medians.forEach((m, i) => assert.equal(m, 255, `papír v pruhu ${i}: ${medians}`));
    for (const x of [TEXT_X0 + 50, TEXT_X1 - 50]) {
      for (const y of TEXT_ROWS) assert.ok(out.ucharAt(y, x) < 100, `text ${x},${y}: ${out.ucharAt(y, x)}`);
    }
  });
});

test('enhance zachová slabou tužku jako šedou, ne černou ani bílou', () => {
  withMats((t) => {
    const out = t(S.enhance(cv, shadedPage(t)));
    for (const x of [TEXT_X0 + 50, (TEXT_X0 + TEXT_X1) / 2, TEXT_X1 - 50]) {
      for (const y of PENCIL_ROWS) {
        const v = Math.min(out.ucharAt(y, x), out.ucharAt(y + 1, x));
        const paper = regionMedian(out, x - 5, y + 20, 10, 10);
        assert.ok(v < paper - 50, `tužka ${x},${y} viditelná: ${v} vs papír ${paper}`);
        assert.ok(v > 40, `tužka ${x},${y} není černá: ${v}`);
      }
    }
  });
});

test('enhance prázdného papíru nevyrobí šum ani skvrny', () => {
  withMats((t) => {
    const page = t(new cv.Mat(S.PAGE_H, S.PAGE_W, cv.CV_8UC1, new cv.Scalar(200)));
    const rand = rng(11);
    const d = page.data;
    for (let i = 0; i < d.length; i++) d[i] = 200 + Math.round((rand() - 0.5) * 8);
    const out = t(S.enhance(cv, page));
    let min = 255;
    for (let i = 0; i < out.data.length; i++) min = Math.min(min, out.data[i]);
    assert.ok(min > 200, `nejtmavší pixel ${min}`);
  });
});
