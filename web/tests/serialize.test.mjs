// Tests for serializeRange, chartToFileJSON, and the base64 UTF-8 helpers.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import {
  serializeRange, chartToFileJSON, utf8ToBase64, base64ToUtf8,
} from '../js/serialize.js';
import {
  parseRange, buildChart, allHands, handAt, RANKS,
} from '../js/domain.js';
import { CHART_FILES } from '../js/charts.js';

const __filename = fileURLToPath(import.meta.url);
const WEB_DIR = path.resolve(path.dirname(__filename), '..');

async function readChart(rel) {
  const text = await readFile(path.resolve(WEB_DIR, rel), 'utf8');
  return { text, obj: JSON.parse(text), chart: buildChart(JSON.parse(text)) };
}

// Deep structural comparison of hand sets.
function setsEqual(a, b) {
  if (a.size !== b.size) return false;
  for (const x of a) if (!b.has(x)) return false;
  return true;
}

// ---------------------- serializeRange round-trip ----------------------

test('serializeRange: empty set → empty string, and round-trips', () => {
  assert.equal(serializeRange(new Set()), '');
  assert.deepEqual([...parseRange(serializeRange(new Set()))], []);
});

test('serializeRange: AA alone → "AA", not "AA+"', () => {
  const set = new Set(['AA']);
  assert.equal(serializeRange(set), 'AA');
  assert.ok(setsEqual(parseRange('AA'), set));
});

test('serializeRange: full pair run → "22+"', () => {
  const set = parseRange('22+');
  assert.equal(serializeRange(set), '22+');
});

test('serializeRange: partial pair run → "77+"', () => {
  const set = parseRange('77+');
  assert.equal(serializeRange(set), '77+');
});

test('serializeRange: non-top-anchored pairs stay as singles', () => {
  // {77, 55, 33} — none reaches AA, so no "+".
  const set = new Set(['77', '55', '33']);
  assert.equal(serializeRange(set), '77, 55, 33');
});

test('serializeRange: {AA, QQ} (gap) → "AA, QQ"', () => {
  // Run anchored at AA has length 1 → "AA", then QQ.
  const set = new Set(['AA', 'QQ']);
  assert.equal(serializeRange(set), 'AA, QQ');
});

test('serializeRange: suited {A2s..AKs} → "A2s+"', () => {
  const set = parseRange('A2s+');
  assert.equal(serializeRange(set), 'A2s+');
});

test('serializeRange: suited {AKs} → "AKs" (not "AKs+")', () => {
  // Spec: a run of length 1 for suited emits the single token.
  const set = new Set(['AKs']);
  assert.equal(serializeRange(set), 'AKs');
});

test('serializeRange: suited {AKs, AQs, A5s} → "AQs+, A5s"', () => {
  const set = new Set(['AKs', 'AQs', 'A5s']);
  assert.equal(serializeRange(set), 'AQs+, A5s');
});

test('serializeRange: suited {AKs, A5s} → "AKs, A5s"', () => {
  const set = new Set(['AKs', 'A5s']);
  assert.equal(serializeRange(set), 'AKs, A5s');
});

test('serializeRange: offsuit "K9o+" and single tokens behave like suited', () => {
  const run = parseRange('K9o+');
  assert.equal(serializeRange(run), 'K9o+');
  assert.equal(serializeRange(new Set(['KQo'])), 'KQo');
  const mix = new Set(['KQo', 'KJo', 'K8o']);
  assert.equal(serializeRange(mix), 'KJo+, K8o');
});

test('serializeRange: ordering is pairs, suited A..3, offsuit A..3', () => {
  const set = parseRange('55+, A3s+, K9s+, Q9s+, J9s+, T9s, T8s, 98s, 87s, ATo+, KQo');
  const str = serializeRange(set);
  // Pairs come first, then suited by high rank A, K, Q, J, T, 9, 8, then
  // offsuit by high rank. We check some ordering constraints rather than
  // the exact string (which depends on our run rules).
  const parts = str.split(', ');
  assert.ok(parts[0] === '55+', 'pairs come first');
  // suited A high must appear before suited K high
  const firstA = parts.findIndex(p => /^A.s/.test(p));
  const firstK = parts.findIndex(p => /^K.s/.test(p));
  assert.ok(firstA < firstK, 'A-high suited before K-high suited');
  // offsuit comes after all suited
  const firstO = parts.findIndex(p => /o(\+)?$/.test(p));
  const lastS = parts.map((p, i) => /s(\+)?$/.test(p) ? i : -1).filter(i => i >= 0).pop();
  assert.ok(firstO > lastS, 'suited block before offsuit block');
  // And the round-trip matches.
  assert.ok(setsEqual(parseRange(str), set));
});

test('serializeRange: parseRange(serializeRange(S)) === S for every chart field', async () => {
  for (const rel of CHART_FILES) {
    const text = await readFile(path.resolve(WEB_DIR, rel), 'utf8');
    const obj = JSON.parse(text);
    for (const [k, v] of Object.entries(obj)) {
      if (typeof v !== 'string') continue;
      if (k === 'scenario' || k === 'chartType' || k === 'openSize' || k === 'note') continue;
      const set = parseRange(v);
      if (set.size === 0 && v.trim() === '') {
        assert.equal(serializeRange(set), '');
        continue;
      }
      const canonical = serializeRange(set);
      const round = parseRange(canonical);
      assert.ok(setsEqual(round, set), `round-trip failed for ${rel}:${k}: ${v} → ${canonical}`);
    }
  }
});

test('serializeRange: 200 random subsets round-trip', () => {
  const universe = allHands();
  let rng = 1337;
  // Little deterministic LCG so the test is reproducible.
  const rand = () => {
    rng = (rng * 1664525 + 1013904223) >>> 0;
    return rng / 0xffffffff;
  };
  for (let i = 0; i < 200; i++) {
    const sub = new Set();
    for (const h of universe) if (rand() < 0.3) sub.add(h);
    const canonical = serializeRange(sub);
    const round = parseRange(canonical);
    assert.ok(setsEqual(round, sub),
      `round-trip failed on random subset #${i} (size=${sub.size}): "${canonical}"`);
  }
});

test('serializeRange: full universe → every pair, suited and offsuit token', () => {
  const universe = new Set(allHands());
  const str = serializeRange(universe);
  const round = parseRange(str);
  assert.equal(round.size, 169);
  assert.ok(setsEqual(round, universe));
});

// ---------------------- chartToFileJSON ----------------------

test('chartToFileJSON: byte-identical with no edits for all 23 charts', async () => {
  for (const rel of CHART_FILES) {
    const { text, chart } = await readChart(rel);
    const out = chartToFileJSON(text, chart.entries);
    assert.equal(out, text, `byte-identical no-edit for ${rel}`);
  }
});

test('chartToFileJSON: emptying a field keeps it as "" and parses', async () => {
  const { text, chart } = await readChart('charts/defense/bb_vs_utg.json');
  const entries = new Map();
  for (const [h, ca] of chart.entries) {
    // Drop every pure call entry → the "call" field becomes empty.
    if (ca.kind === 'pure' && ca.action === 'call') continue;
    entries.set(h, ca);
  }
  const out = chartToFileJSON(text, entries);
  const parsed = JSON.parse(out);
  assert.equal(parsed.call, '');
  // Still passes buildChart.
  const rebuilt = buildChart(parsed);
  assert.equal(rebuilt.entries.size,
    [...chart.entries.values()].filter(ca => !(ca.kind === 'pure' && ca.action === 'call')).length);
});

test('chartToFileJSON: adding a field creates it after the existing range fields', async () => {
  // btn_vs_co.json has fields: threeBet, mixed3betCall, call. It does NOT
  // have mixed3betFold. We add one entry → mixed3betFold appears, inserted
  // after the last range field present ("call").
  const { text, chart } = await readChart('charts/defense/btn_vs_co.json');
  const entries = new Map();
  for (const [h, ca] of chart.entries) entries.set(h, ca);
  entries.set('T7s', { kind: 'mixed', aggressive: '3bet', passive: 'fold' });
  const out = chartToFileJSON(text, entries);
  const parsed = JSON.parse(out);
  assert.equal(parsed.mixed3betFold, 'T7s');
  // Order: existing range fields keep positions, new field is after the last.
  const keys = Object.keys(parsed);
  const lastRange = Math.max(
    keys.indexOf('threeBet'),
    keys.indexOf('mixed3betCall'),
    keys.indexOf('call'),
  );
  const newIdx = keys.indexOf('mixed3betFold');
  assert.ok(newIdx > lastRange, `mixed3betFold index ${newIdx} must be after last range field ${lastRange}`);
  // Still passes buildChart.
  buildChart(parsed);
});

test('chartToFileJSON: non-range fields are preserved verbatim', async () => {
  const { text, chart } = await readChart('charts/rfi/sb.json');
  // sb.json has openSize + note + range in that order; mutate range only.
  const entries = new Map(chart.entries);
  entries.delete('AA'); // drop AA from the open range
  const out = chartToFileJSON(text, entries);
  const parsed = JSON.parse(out);
  const original = JSON.parse(text);
  assert.equal(parsed.openSize, original.openSize);
  assert.equal(parsed.note, original.note);
  assert.notEqual(parsed.range, original.range);
  buildChart(parsed);
});

test('chartToFileJSON: output always passes buildChart', async () => {
  for (const rel of CHART_FILES) {
    const { text, chart } = await readChart(rel);
    const out = chartToFileJSON(text, chart.entries);
    const parsed = JSON.parse(out);
    buildChart(parsed); // throws on failure
  }
});

test('chartToFileJSON: rfi range may be ""', () => {
  const originalText = JSON.stringify({
    scenario: 'rfi.utg', chartType: 'rfi', openSize: '2.5bb', range: 'AA, KK',
  }, null, 2) + '\n';
  const out = chartToFileJSON(originalText, new Map());
  const parsed = JSON.parse(out);
  assert.equal(parsed.range, '');
});

// ---------------------- base64 UTF-8 ----------------------

test('base64 UTF-8 round-trips plain ASCII', () => {
  const txt = 'hello world';
  assert.equal(base64ToUtf8(utf8ToBase64(txt)), txt);
  assert.equal(utf8ToBase64(txt), 'aGVsbG8gd29ybGQ=');
});

test('base64 UTF-8 round-trips multibyte characters', () => {
  const txt = '—♠ Open 2.5bb — notes here ✓';
  const b64 = utf8ToBase64(txt);
  assert.equal(base64ToUtf8(b64), txt);
});

test('base64 UTF-8 round-trips a chart file verbatim', async () => {
  const { text } = await readChart('charts/rfi/sb.json');
  const b64 = utf8ToBase64(text);
  assert.equal(base64ToUtf8(b64), text);
});

test('base64 UTF-8 decoder tolerates whitespace from GitHub payload', () => {
  const txt = 'abc';
  const b64 = utf8ToBase64(txt);
  const withNewlines = b64.replace(/.{2}/g, m => m + '\n');
  assert.equal(base64ToUtf8(withNewlines), txt);
});
