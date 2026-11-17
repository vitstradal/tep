(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.TepScanner = factory();
}(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var PAGE_W = 1240;
  var PAGE_H = 1754;
  var DETECT_SIZE = 800;
  var MIN_SHEET_AREA = 0.2;
  var MAX_SHEET_AREA = 0.98;
  var CANNY_LOW = 30;
  var CANNY_HIGH = 90;
  var EDGE_INSET = 2;
  var POLY_EPSILONS = [0.02, 0.035, 0.05];
  var BG_SCALE = 4;
  var BG_DILATE = 1 / 60;
  var BG_BLUR = 1 / 20;
  var BLACK_PERCENTILE = 0.005;
  var GAMMA = 1.4;

  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }

  function odd(n) { n = Math.max(3, Math.round(n)); return n % 2 ? n : n + 1; }

  function orderCorners(points) {
    var cx = 0, cy = 0;
    points.forEach(function (p) { cx += p[0] / 4; cy += p[1] / 4; });
    var sorted = points.slice().sort(function (a, b) {
      return Math.atan2(a[1] - cy, a[0] - cx) - Math.atan2(b[1] - cy, b[0] - cx);
    });
    var start = 0;
    sorted.forEach(function (p, i) { if (p[0] + p[1] < sorted[start][0] + sorted[start][1]) start = i; });
    return sorted.slice(start).concat(sorted.slice(0, start)).map(function (p) { return [p[0], p[1]]; });
  }

  function fullFrame(w, h) {
    return [[0, 0], [w - 1, 0], [w - 1, h - 1], [0, h - 1]];
  }

  function clampCorners(corners, w, h) {
    return corners.map(function (p) {
      return [Math.min(w - 1, Math.max(0, p[0])), Math.min(h - 1, Math.max(0, p[1]))];
    });
  }

  // Posune rohy o `px` ke středu, aby do stránky nezasahoval proužek pozadí.
  function inset(points, px) {
    var cx = 0, cy = 0;
    points.forEach(function (p) { cx += p[0] / 4; cy += p[1] / 4; });
    return points.map(function (p) {
      var d = Math.hypot(p[0] - cx, p[1] - cy) || 1;
      return [p[0] + (cx - p[0]) * px / d, p[1] + (cy - p[1]) * px / d];
    });
  }

  function toGray(cv, src) {
    var gray = new cv.Mat();
    if (src.channels() === 4) cv.cvtColor(src, gray, cv.COLOR_RGBA2GRAY);
    else if (src.channels() === 3) cv.cvtColor(src, gray, cv.COLOR_RGB2GRAY);
    else src.copyTo(gray);
    return gray;
  }

  function resized(cv, src, scale, interpolation) {
    var dst = new cv.Mat();
    var size = new cv.Size(Math.max(1, Math.round(src.cols * scale)), Math.max(1, Math.round(src.rows * scale)));
    cv.resize(src, dst, size, 0, 0, interpolation);
    return dst;
  }

  // Největší konvexní čtyřúhelník z obrysů binárního obrázku, plocha v mezích.
  function largestQuad(cv, binary, mode, minArea, maxArea) {
    var contours = new cv.MatVector();
    var hierarchy = new cv.Mat();
    var best = null;
    var bestArea = 0;
    try {
      cv.findContours(binary, contours, hierarchy, mode, cv.CHAIN_APPROX_SIMPLE);
      for (var i = 0; i < contours.size(); i++) {
        var contour = contours.get(i);
        var hull = new cv.Mat();
        try {
          if (cv.contourArea(contour) < minArea * 0.9) continue;
          cv.convexHull(contour, hull, false, true);
          var peri = cv.arcLength(hull, true);
          for (var e = 0; e < POLY_EPSILONS.length; e++) {
            var approx = new cv.Mat();
            try {
              cv.approxPolyDP(hull, approx, POLY_EPSILONS[e] * peri, true);
              if (approx.rows !== 4 || !cv.isContourConvex(approx)) continue;
              var area = cv.contourArea(approx);
              if (area >= minArea && area <= maxArea && area > bestArea &&
                  cv.contourArea(contour) >= 0.9 * area) {
                bestArea = area;
                best = [];
                for (var k = 0; k < 4; k++) best.push([approx.intAt(k, 0), approx.intAt(k, 1)]);
              }
              break;
            } finally { approx.delete(); }
          }
        } finally { hull.delete(); contour.delete(); }
      }
    } finally { contours.delete(); hierarchy.delete(); }
    return best;
  }

  function findSheet(cv, rgba) {
    var scale = Math.min(1, DETECT_SIZE / Math.max(rgba.cols, rgba.rows));
    var small = resized(cv, rgba, scale, cv.INTER_AREA);
    var gray = toGray(cv, small);
    small.delete();
    var edges = new cv.Mat();
    var otsu = new cv.Mat();
    var kernel = cv.getStructuringElement(cv.MORPH_RECT, new cv.Size(3, 3));
    try {
      var frameArea = gray.cols * gray.rows;
      var minArea = MIN_SHEET_AREA * frameArea;
      var maxArea = MAX_SHEET_AREA * frameArea;
      cv.GaussianBlur(gray, gray, new cv.Size(5, 5), 0);
      cv.Canny(gray, edges, CANNY_LOW, CANNY_HIGH);
      cv.dilate(edges, edges, kernel);
      var quad = largestQuad(cv, edges, cv.RETR_LIST, minArea, maxArea);
      if (!quad) {
        cv.threshold(gray, otsu, 0, 255, cv.THRESH_BINARY + cv.THRESH_OTSU);
        quad = largestQuad(cv, otsu, cv.RETR_EXTERNAL, minArea, maxArea);
      }
      if (!quad) return null;
      return clampCorners(orderCorners(inset(quad, EDGE_INSET).map(function (p) {
        return [p[0] / scale, p[1] / scale];
      })), rgba.cols, rgba.rows);
    } finally {
      gray.delete(); edges.delete(); otsu.delete(); kernel.delete();
    }
  }

  function warpToPage(cv, rgba, corners) {
    var c = orderCorners(corners);
    var quadW = Math.max(dist(c[0], c[1]), dist(c[3], c[2]));
    var quadH = Math.max(dist(c[0], c[3]), dist(c[1], c[2]));
    var landscape = quadW > quadH;
    // Před vyrovnáním zmenšit průměrováním, aby tenké čáry nezmizely mezi vzorky.
    var scale = Math.min(1, 1.1 * PAGE_H / Math.max(quadW, quadH));
    var srcPts = [];
    c.forEach(function (p) { srcPts.push(p[0] * scale, p[1] * scale); });
    var dstPts = landscape
      ? [PAGE_W, 0, PAGE_W, PAGE_H, 0, PAGE_H, 0, 0]
      : [0, 0, PAGE_W, 0, PAGE_W, PAGE_H, 0, PAGE_H];
    var gray = toGray(cv, rgba);
    var smaller = null, src = null, dst = null, m = null;
    var out = new cv.Mat();
    try {
      if (scale < 1) smaller = resized(cv, gray, scale, cv.INTER_AREA);
      src = cv.matFromArray(4, 1, cv.CV_32FC2, srcPts);
      dst = cv.matFromArray(4, 1, cv.CV_32FC2, dstPts);
      m = cv.getPerspectiveTransform(src, dst);
      cv.warpPerspective(smaller || gray, out, m, new cv.Size(PAGE_W, PAGE_H), cv.INTER_CUBIC, cv.BORDER_REPLICATE);
      return out;
    } catch (e) {
      out.delete();
      throw e;
    } finally {
      [gray, smaller, src, dst, m].forEach(function (mat) { if (mat) mat.delete(); });
    }
  }

  function percentile(hist, total, p) {
    var limit = p * total;
    var acc = 0;
    for (var v = 0; v < 256; v++) {
      acc += hist[v];
      if (acc > limit) return v;
    }
    return 255;
  }

  function enhance(cv, gray) {
    var small = resized(cv, gray, 1 / BG_SCALE, cv.INTER_AREA);
    var longSide = Math.max(small.cols, small.rows);
    var kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, new cv.Size(odd(longSide * BG_DILATE), odd(longSide * BG_DILATE)));
    var bg = new cv.Mat();
    var out = new cv.Mat();
    try {
      cv.dilate(small, small, kernel);
      var blur = odd(longSide * BG_BLUR);
      cv.GaussianBlur(small, small, new cv.Size(blur, blur), 0, 0, cv.BORDER_REPLICATE);
      cv.resize(small, bg, new cv.Size(gray.cols, gray.rows), 0, 0, cv.INTER_LINEAR);
      cv.divide(gray, bg, out, 255);

      var data = out.data;
      var hist = new Array(256).fill(0);
      for (var i = 0; i < data.length; i++) hist[data[i]]++;
      var p50 = percentile(hist, data.length, 0.5);
      var p25 = percentile(hist, data.length, 0.25);
      var white = Math.max(1, p50 - Math.max(4, 3 * (p50 - p25)), 0.85 * p50);
      var black = Math.min(percentile(hist, data.length, BLACK_PERCENTILE), 0.5 * white);
      var lut = new Uint8Array(256);
      for (var v = 0; v < 256; v++) {
        var t = Math.min(1, Math.max(0, (v - black) / (white - black)));
        lut[v] = Math.round(255 * Math.pow(t, GAMMA));
      }
      for (var j = 0; j < data.length; j++) data[j] = lut[data[j]];
      return out;
    } catch (e) {
      out.delete();
      throw e;
    } finally {
      small.delete(); kernel.delete(); bg.delete();
    }
  }

  function scanPage(cv, rgba, corners) {
    var c = corners || findSheet(cv, rgba) || fullFrame(rgba.cols, rgba.rows);
    var warped = warpToPage(cv, rgba, c);
    try {
      return enhance(cv, warped);
    } finally {
      warped.delete();
    }
  }

  return {
    PAGE_W: PAGE_W,
    PAGE_H: PAGE_H,
    findSheet: findSheet,
    orderCorners: orderCorners,
    fullFrame: fullFrame,
    clampCorners: clampCorners,
    warpToPage: warpToPage,
    enhance: enhance,
    scanPage: scanPage
  };
}));
