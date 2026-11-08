// Color palettes. In this version the palette lives in `web/palette.json`
// in the repo — not in localStorage. The runtime consumes it as plain
// objects; writing new values back to the repo is done by the editor flow
// (app.js), not here.

// null for `fold` means "use the semantic auto-adapting default from CSS".
export const DEFAULT_PALETTE = Object.freeze({
  fold:          null,
  call:          '#38B359',
  open:          '#EB4D4D',
  '3bet':        '#EB4D4D',
  '4bet':        '#EB4D4D',
  '5bet':        '#EB4D4D',
  '3betCall':    '#F5CC33',
  '3betFold':    '#F5CC33',
  '4betCall':    '#F5CC33',
  '5betCall':    '#F5CC33',
});

export const DEFAULT_RFI_PALETTE = Object.freeze({
  utg:   '#EB4D4D',
  mp:    '#F28C26',
  co:    '#F5CC33',
  btnSb: '#38B359',
  fold:  null,
});

// Default fold colors used when `fold === null`. Resolved against the
// current `prefers-color-scheme` so legend swatches and painted cells
// both agree.
export function resolveAutoFoldColor(isDark = systemIsDark()) {
  return isDark ? '#2C2C2E' : '#E5E5EA';
}

export function systemIsDark() {
  if (typeof matchMedia !== 'function') return false;
  return matchMedia('(prefers-color-scheme: dark)').matches;
}

const HEX = /^#[0-9a-fA-F]{6}$/;

function sanitise(obj, defaults) {
  const out = { ...defaults };
  if (!obj || typeof obj !== 'object') return out;
  for (const k of Object.keys(defaults)) {
    if (!(k in obj)) continue;
    const v = obj[k];
    if (v === null) { out[k] = null; continue; }
    if (typeof v === 'string' && HEX.test(v)) out[k] = v;
  }
  return out;
}

// Parse a palette.json payload. Missing or invalid values fall back to the
// built-in defaults. Returns `{ palette, rfiPalette }` (both plain objects).
export function parsePaletteFile(text) {
  try {
    const raw = (typeof text === 'string') ? JSON.parse(text) : text;
    const actions = raw?.actions ?? raw?.palette;
    const rfi = raw?.rfi ?? raw?.rfiPalette;
    return {
      palette: sanitise(actions, DEFAULT_PALETTE),
      rfiPalette: sanitise(rfi, DEFAULT_RFI_PALETTE),
    };
  } catch {
    return { palette: { ...DEFAULT_PALETTE }, rfiPalette: { ...DEFAULT_RFI_PALETTE } };
  }
}

// Serialize to the exact file format we want in the repo (2-space JSON +
// trailing newline). Preserves key order from DEFAULT_PALETTE and
// DEFAULT_RFI_PALETTE so the output is stable regardless of in-memory
// mutation order.
export function serializePaletteFile(palette, rfiPalette) {
  const ordered = (obj, defaults) => {
    const out = {};
    for (const k of Object.keys(defaults)) out[k] = obj[k] ?? null;
    return out;
  };
  const obj = {
    actions: ordered(palette, DEFAULT_PALETTE),
    rfi:     ordered(rfiPalette, DEFAULT_RFI_PALETTE),
  };
  return JSON.stringify(obj, null, 2) + '\n';
}

// Deep-ish structural equality for a palette pair.
// Hex colors compare case-insensitively: <input type=color> reports lowercase
// ("#38b359") while palette.json uses uppercase ("#38B359").
const sameColor = (x, y) =>
  x === y || (x != null && y != null && String(x).toLowerCase() === String(y).toLowerCase());

export function palettesEqual(a, b) {
  for (const k of Object.keys(DEFAULT_PALETTE)) if (!sameColor(a.palette[k], b.palette[k])) return false;
  for (const k of Object.keys(DEFAULT_RFI_PALETTE)) if (!sameColor(a.rfiPalette[k], b.rfiPalette[k])) return false;
  return true;
}

// ---- Chart action → color -------------------------------------------------

export function colorForAction(palette, action) {
  if (action === 'fold') return palette.fold ?? resolveAutoFoldColor();
  return palette[action];
}

export function colorForChartAction(palette, ca) {
  if (!ca) return palette.fold ?? resolveAutoFoldColor();
  if (ca.kind === 'pure') return colorForAction(palette, ca.action);
  if (ca.aggressive === '3bet' && ca.passive === 'call') return palette['3betCall'];
  if (ca.aggressive === '3bet' && ca.passive === 'fold') return palette['3betFold'];
  if (ca.aggressive === '4bet' && ca.passive === 'call') return palette['4betCall'];
  if (ca.aggressive === '5bet' && ca.passive === 'call') return palette['5betCall'];
  return palette['3betCall'];
}

// F17: paint value for a cell / swatch / pill. Returns a CSS background
// value (solid color or a hard-edged 50/50 linear-gradient for mixed
// actions), a foreground text color, and whether the text needs a dark
// outline because the two halves disagree on readable text color
// (AC17.4). The passive leg of a mixed action always resolves against the
// palette's current pure color (fold → palette.fold ?? auto fold gray), so
// e.g. 3-Bet/Fold uses the active fold color, not any stored mixed slot.
export function cellFill(palette, ca) {
  if (!ca || (ca.kind === 'pure' && ca.action === 'fold')) {
    const c = colorForAction(palette, 'fold');
    return { background: c, fg: foregroundOn(c), outline: false };
  }
  if (ca.kind === 'pure') {
    const c = colorForAction(palette, ca.action);
    return { background: c, fg: foregroundOn(c), outline: false };
  }
  if (ca.kind === 'mixed') {
    const left = colorForAction(palette, ca.aggressive);
    const right = colorForAction(palette, ca.passive);
    const background = `linear-gradient(to right, ${left} 50%, ${right} 50%)`;
    const fgL = foregroundOn(left);
    const fgR = foregroundOn(right);
    if (fgL === fgR) return { background, fg: fgL, outline: false };
    return { background, fg: '#ffffff', outline: true };
  }
  const c = colorForAction(palette, 'fold');
  return { background: c, fg: foregroundOn(c), outline: false };
}

// ---- RFI ring → color -----------------------------------------------------

export function colorForRing(palette, ring) {
  switch (ring) {
    case 'UTG':    return palette.utg;
    case 'MP':     return palette.mp;
    case 'CO':     return palette.co;
    case 'BTN/SB': return palette.btnSb;
    default:       return palette.fold ?? resolveAutoFoldColor();
  }
}

// ---- Contrast -------------------------------------------------------------

export function luminance(hex) {
  if (!hex || hex[0] !== '#') return 0;
  const n = parseInt(hex.slice(1), 16);
  const r = ((n >> 16) & 0xff) / 255;
  const g = ((n >> 8)  & 0xff) / 255;
  const b = (n & 0xff) / 255;
  return 0.299 * r + 0.587 * g + 0.114 * b;
}

export function foregroundOn(hex) {
  return luminance(hex) > 0.6 ? '#111' : '#ffffff';
}
