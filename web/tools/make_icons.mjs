#!/usr/bin/env node
// Generate PWA icons without any dependency. Draws a poker-themed design:
// a dark green felt background with a concentric "range chart" chevron
// pattern (UTG red → MP orange → CO yellow → BTN/SB green). Writes raw
// RGBA to a PNG via zlib. Pure built-ins; no PIL / canvas / ImageMagick.
//
// Usage:  node web/tools/make_icons.mjs
// Output: web/icons/{apple-touch-icon.png, icon-192.png, icon-512.png}

import { writeFileSync, mkdirSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const outDir = path.resolve(path.dirname(__filename), '..', 'icons');

// CRC32 (standard IEEE 802.3 polynomial, matches PNG spec).
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function makeChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function encodePNG(width, height, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // color type RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace
  const stride = width * 4;
  // Each scanline gets a leading filter byte (0 = None).
  const scanlines = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    scanlines[y * (stride + 1)] = 0;
    rgba.copy(scanlines, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const idat = deflateSync(scanlines, { level: 9 });
  return Buffer.concat([
    sig,
    makeChunk('IHDR', ihdr),
    makeChunk('IDAT', idat),
    makeChunk('IEND', Buffer.alloc(0)),
  ]);
}

function hex(h) {
  const n = parseInt(h.replace('#', ''), 16);
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff, 255];
}

function putPixel(rgba, size, x, y, c) {
  if (x < 0 || y < 0 || x >= size || y >= size) return;
  const i = (y * size + x) * 4;
  rgba[i] = c[0];
  rgba[i + 1] = c[1];
  rgba[i + 2] = c[2];
  rgba[i + 3] = c[3];
}

function fillRect(rgba, size, x0, y0, w, h, c) {
  for (let y = y0; y < y0 + h; y++) {
    for (let x = x0; x < x0 + w; x++) putPixel(rgba, size, x, y, c);
  }
}

function roundRectBG(rgba, size, c) {
  // Approximate rounded corners via a per-row inset.
  const r = Math.floor(size * 0.22);
  for (let y = 0; y < size; y++) {
    let inset = 0;
    if (y < r) {
      const dy = r - y;
      inset = r - Math.floor(Math.sqrt(Math.max(0, r * r - dy * dy)));
    } else if (y >= size - r) {
      const dy = y - (size - r - 1);
      inset = r - Math.floor(Math.sqrt(Math.max(0, r * r - dy * dy)));
    }
    for (let x = inset; x < size - inset; x++) putPixel(rgba, size, x, y, c);
  }
}

function drawIcon(size) {
  // RGBA, initially fully transparent.
  const rgba = Buffer.alloc(size * size * 4);
  const felt = hex('#0F3F2A');  // dark green felt
  const ringColors = [
    hex('#EB4D4D'), // UTG red
    hex('#F28C26'), // MP orange
    hex('#F5CC33'), // CO yellow
    hex('#38B359'), // BTN/SB green
    hex('#5C5C62'), // fold-ish gray
  ];
  roundRectBG(rgba, size, felt);

  // Center 13×13 chevron grid (ring = min(row, col) so the top-left corner
  // is "tightest" / UTG and the bottom-right is "widest" / fold).
  const cellStep = Math.max(2, Math.floor(size * 0.065));
  const gap = Math.max(1, Math.floor(size * 0.004));
  const cell = cellStep - gap;
  const gridSize = cellStep * 13 - gap;
  const ox = Math.floor((size - gridSize) / 2);
  const oy = Math.floor((size - gridSize) / 2);
  for (let r = 0; r < 13; r++) {
    for (let c = 0; c < 13; c++) {
      const ring = Math.min(r, c);
      const col = ringColors[Math.min(ring, ringColors.length - 1)];
      fillRect(rgba, size, ox + c * cellStep, oy + r * cellStep, cell, cell, col);
    }
  }
  return rgba;
}

mkdirSync(outDir, { recursive: true });
const targets = [
  ['apple-touch-icon.png', 180],
  ['icon-192.png', 192],
  ['icon-512.png', 512],
];
for (const [name, size] of targets) {
  const rgba = drawIcon(size);
  const png = encodePNG(size, size, rgba);
  const p = path.join(outDir, name);
  writeFileSync(p, png);
  console.log('wrote', p, '(', png.length, 'bytes )');
}
