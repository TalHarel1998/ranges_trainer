// Pure serializer: hand sets → canonical range strings, chart entries →
// full file JSON text, and UTF-8-safe base64 encode/decode. Imported from
// Node tests as well as the browser.

import { RANKS, RANK_INDEX, parseHand, parseRange } from './domain.js';

// ---- serializeRange -------------------------------------------------------
//
// Canonical form (chosen for this project):
//   1. Pairs first, then suited (A..3 high), then offsuit (A..3 high).
//   2. Pairs:
//        * Find the longest consecutive run anchored at AA (AA, KK, QQ, …).
//        * If the run has ≥2 pairs → emit `XX+` where XX is the lowest pair
//          in the run.
//        * If the run has exactly 1 pair (just AA) → emit `AA` (no `+`).
//        * All pairs below the run → single tokens, high to low.
//   3. Suited (and offsuit, identically) for each high rank, A → 3:
//        * The anchor is high-1 (e.g. K for A, Q for K).
//        * Find the longest consecutive run of low ranks anchored at that
//          anchor.
//        * If the run has ≥2 lows → emit `HLs+` where L is the lowest in
//          the run.
//        * If the run has exactly 1 low (just high-1) → emit `H(high-1)s`.
//        * All remaining lows below the run → single tokens, high to low.
//   4. Tokens joined with ", ".
//
// Round-trip invariant: `parseRange(serializeRange(S)) == S` for every S of
// valid hand classes. Verified by Node tests across all 23 chart fields and
// 200+ random subsets.

export function serializeRange(set) {
  const hands = Array.from(set ?? []);
  if (hands.length === 0) return '';

  const pairIdx = [];                     // list of rank indices (0 = A … 12 = 2)
  const suitedByHigh = new Map();         // highIdx → sorted array of lowIdx
  const offsuitByHigh = new Map();

  for (const sym of hands) {
    const p = parseHand(sym);
    if (!p) throw new Error(`serializeRange: invalid hand '${sym}'`);
    if (p.isPair) {
      pairIdx.push(RANK_INDEX[p.high]);
    } else {
      const dest = p.isSuited ? suitedByHigh : offsuitByHigh;
      const hi = RANK_INDEX[p.high];
      const arr = dest.get(hi) || [];
      arr.push(RANK_INDEX[p.low]);
      dest.set(hi, arr);
    }
  }

  const tokens = [];

  // ---- pairs ----
  if (pairIdx.length > 0) {
    pairIdx.sort((a, b) => a - b);        // 0 = A first, 12 = 2 last
    // Longest run anchored at AA (idx 0).
    let runEnd = -1;
    if (pairIdx[0] === 0) {
      runEnd = 0;
      for (let i = 1; i < pairIdx.length; i++) {
        if (pairIdx[i] === pairIdx[i - 1] + 1) runEnd = pairIdx[i];
        else break;
      }
    }
    const runLen = runEnd + 1; // run covers idx 0..runEnd
    if (runLen >= 2) {
      tokens.push(RANKS[runEnd] + RANKS[runEnd] + '+');
    } else if (runLen === 1) {
      tokens.push('AA');
    }
    for (const idx of pairIdx) {
      if (idx <= runEnd) continue;
      tokens.push(RANKS[idx] + RANKS[idx]);
    }
  }

  emitNonPairs(tokens, suitedByHigh, 's');
  emitNonPairs(tokens, offsuitByHigh, 'o');

  return tokens.join(', ');
}

function emitNonPairs(tokens, byHigh, suit) {
  const highs = [...byHigh.keys()].sort((a, b) => a - b); // A first (0)
  for (const hi of highs) {
    const lows = byHigh.get(hi).slice().sort((a, b) => a - b);
    const anchor = hi + 1;                     // index of (high - 1)
    let runEnd = -1;                           // highest index in the run
    if (lows[0] === anchor) {
      runEnd = anchor;
      for (let i = 1; i < lows.length; i++) {
        if (lows[i] === lows[i - 1] + 1) runEnd = lows[i];
        else break;
      }
    }
    const runLen = (runEnd >= 0) ? (runEnd - anchor + 1) : 0;
    if (runLen >= 2) {
      tokens.push(RANKS[hi] + RANKS[runEnd] + suit + '+');
    } else if (runLen === 1) {
      tokens.push(RANKS[hi] + RANKS[anchor] + suit);
    }
    for (const low of lows) {
      if (runLen > 0 && low <= runEnd && low >= anchor) continue;
      tokens.push(RANKS[hi] + RANKS[low] + suit);
    }
  }
}

// ---- chartToFileJSON ------------------------------------------------------

const FIELDS_BY_TYPE = Object.freeze({
  rfi:     ['range'],
  defense: ['threeBet', 'mixed3betCall', 'mixed3betFold', 'call'],
  vs3bet:  ['fourBet',  'mixed4betCall', 'call'],
  vs4bet:  ['fiveBet',  'mixed5betCall', 'call'],
});

function fieldsForType(chartType) {
  return FIELDS_BY_TYPE[chartType] || [];
}

function entryIterable(entries) {
  if (entries instanceof Map) return entries.entries();
  if (entries && typeof entries === 'object') return Object.entries(entries);
  return [];
}

// Translate a hand → ChartAction map into { fieldName: Set<hand> } for the
// chart type. Hands that resolve to pure fold (or missing) are not placed in
// any set (they are implicit folds in the file).
function fieldSetsFromEntries(chartType, entries) {
  const out = {};
  for (const f of fieldsForType(chartType)) out[f] = new Set();
  const assign = (field, hand) => { if (out[field]) out[field].add(hand); };

  for (const [hand, ca] of entryIterable(entries)) {
    if (!ca) continue;
    if (ca.kind === 'pure') {
      if (ca.action === 'fold') continue;
      switch (chartType) {
        case 'rfi':
          if (ca.action === 'open') assign('range', hand);
          break;
        case 'defense':
          if (ca.action === '3bet') assign('threeBet', hand);
          else if (ca.action === 'call') assign('call', hand);
          break;
        case 'vs3bet':
          if (ca.action === '4bet') assign('fourBet', hand);
          else if (ca.action === 'call') assign('call', hand);
          break;
        case 'vs4bet':
          if (ca.action === '5bet') assign('fiveBet', hand);
          else if (ca.action === 'call') assign('call', hand);
          break;
      }
    } else if (ca.kind === 'mixed') {
      if (chartType === 'defense' && ca.aggressive === '3bet') {
        if (ca.passive === 'call') assign('mixed3betCall', hand);
        else if (ca.passive === 'fold') assign('mixed3betFold', hand);
      } else if (chartType === 'vs3bet' && ca.aggressive === '4bet' && ca.passive === 'call') {
        assign('mixed4betCall', hand);
      } else if (chartType === 'vs4bet' && ca.aggressive === '5bet' && ca.passive === 'call') {
        assign('mixed5betCall', hand);
      }
    }
  }
  return out;
}

function setsEqual(a, b) {
  if (a.size !== b.size) return false;
  for (const x of a) if (!b.has(x)) return false;
  return true;
}

// Build the new file text from the original file text + the edited entry
// map (same shape as domain `chart.entries`). Preserves key order and keeps
// unchanged field strings byte-for-byte so that AC13.3 holds. Output is
// 2-space JSON + a trailing newline.
export function chartToFileJSON(originalText, editedEntries) {
  const obj = JSON.parse(originalText);
  const chartType = obj.chartType;
  const fields = fieldsForType(chartType);
  const editedSets = fieldSetsFromEntries(chartType, editedEntries);

  // Walk existing keys in order, replacing range fields when their set
  // changed (and preserving the exact source string when it did not).
  const outEntries = [];
  const presentFields = new Set();
  let lastRangeIdx = -1;

  for (const [k, v] of Object.entries(obj)) {
    if (fields.includes(k)) {
      presentFields.add(k);
      const original = v == null ? '' : String(v);
      const originalSet = parseRange(original);
      const editedSet = editedSets[k];
      let value;
      if (setsEqual(originalSet, editedSet)) {
        value = original;                       // preserve byte-for-byte
      } else {
        value = serializeRange(editedSet);      // may be ""
      }
      outEntries.push([k, value]);
      lastRangeIdx = outEntries.length - 1;
    } else {
      outEntries.push([k, v]);
    }
  }

  // Insert any range fields that didn't exist in the original but became
  // non-empty. Place them after the last existing range field, in canonical
  // field order. If no range field existed, append in canonical order.
  const toInsert = [];
  for (const f of fields) {
    if (presentFields.has(f)) continue;
    const s = editedSets[f];
    if (!s || s.size === 0) continue;
    toInsert.push([f, serializeRange(s)]);
  }
  if (toInsert.length > 0) {
    if (lastRangeIdx >= 0) {
      outEntries.splice(lastRangeIdx + 1, 0, ...toInsert);
    } else {
      outEntries.push(...toInsert);
    }
  }

  const out = {};
  for (const [k, v] of outEntries) out[k] = v;
  return JSON.stringify(out, null, 2) + '\n';
}

// ---- Base64 UTF-8 ---------------------------------------------------------
//
// We never want btoa/atob called on strings with code points > 0xFF: those
// throw. Use TextEncoder/TextDecoder in the browser, Buffer in Node.

export function utf8ToBase64(str) {
  if (typeof Buffer !== 'undefined' && typeof Buffer.from === 'function') {
    return Buffer.from(String(str), 'utf8').toString('base64');
  }
  const bytes = new TextEncoder().encode(String(str));
  let bin = '';
  // Chunk to avoid "Maximum call stack size exceeded" for very large files.
  const CHUNK = 0x8000;
  for (let i = 0; i < bytes.length; i += CHUNK) {
    bin += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
  }
  return btoa(bin);
}

export function base64ToUtf8(b64) {
  const cleaned = String(b64).replace(/\s+/g, '');
  if (typeof Buffer !== 'undefined' && typeof Buffer.from === 'function') {
    return Buffer.from(cleaned, 'base64').toString('utf8');
  }
  const bin = atob(cleaned);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new TextDecoder('utf-8').decode(bytes);
}
