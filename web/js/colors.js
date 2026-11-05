// Color palettes with localStorage persistence. The "fold" slot defaults to
// a semantic value that adapts to light/dark mode via CSS; when the user
// picks a specific color we store the hex and that override wins everywhere.

const STORAGE_KEY = 'preflopt.palette.v1';
const RFI_STORAGE_KEY = 'preflopt.rfiPalette.v1';

// null for `fold` means "use the semantic auto-adapting default from CSS".
export const DEFAULT_PALETTE = Object.freeze({
  fold:          null,
  call:          '#38B359', // 0.22, 0.70, 0.35
  open:          '#EB4D4D', // 0.92, 0.30, 0.30
  '3bet':        '#EB4D4D',
  '4bet':        '#EB4D4D',
  '5bet':        '#EB4D4D',
  '3betCall':    '#F5CC33', // 0.96, 0.80, 0.20
  '3betFold':    '#F5CC33',
  '4betCall':    '#F5CC33',
  '5betCall':    '#F5CC33',
});

export const DEFAULT_RFI_PALETTE = Object.freeze({
  utg:   '#EB4D4D',
  mp:    '#F28C26', // 0.95, 0.55, 0.15
  co:    '#F5CC33',
  btnSb: '#38B359',
  fold:  null,
});

// Default colors used when `fold === null`. Resolved against the current
// `prefers-color-scheme` so legend swatches and painted cells both agree.
export function resolveAutoFoldColor(isDark = systemIsDark()) {
  return isDark ? '#2C2C2E' : '#E5E5EA';
}

export function systemIsDark() {
  if (typeof matchMedia !== 'function') return false;
  return matchMedia('(prefers-color-scheme: dark)').matches;
}

function sanitise(obj, defaults) {
  const out = { ...defaults };
  for (const k of Object.keys(defaults)) {
    const v = obj?.[k];
    if (v === null) { out[k] = null; continue; }
    if (typeof v === 'string' && /^#[0-9a-fA-F]{6}$/.test(v)) out[k] = v;
  }
  return out;
}

export function loadPalette() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT_PALETTE };
    return sanitise(JSON.parse(raw), DEFAULT_PALETTE);
  } catch { return { ...DEFAULT_PALETTE }; }
}

export function savePalette(p) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(p)); } catch {}
}

export function loadRFIPalette() {
  try {
    const raw = localStorage.getItem(RFI_STORAGE_KEY);
    if (!raw) return { ...DEFAULT_RFI_PALETTE };
    return sanitise(JSON.parse(raw), DEFAULT_RFI_PALETTE);
  } catch { return { ...DEFAULT_RFI_PALETTE }; }
}

export function saveRFIPalette(p) {
  try { localStorage.setItem(RFI_STORAGE_KEY, JSON.stringify(p)); } catch {}
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
  return palette['3betCall']; // unexpected mix: fall back to 3-bet/call
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
//
// BT.601 luminance on normalised sRGB. "> 0.6 → dark text, else white"
// matches the Swift ColorPalette.contrastingForeground.

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
