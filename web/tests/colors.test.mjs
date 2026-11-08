// Tests for the pure color helpers in colors.js — focused on the F17
// `cellFill` helper that computes a cell / swatch / pill background.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  DEFAULT_PALETTE,
  cellFill,
  colorForChartAction,
  foregroundOn,
  resolveAutoFoldColor,
} from '../js/colors.js';

// A palette with an explicit (non-null) fold color so tests don't depend
// on an auto-detected system scheme.
const PAL = Object.freeze({
  ...DEFAULT_PALETTE,
  fold: '#E5E5EA',
});

const PURE = (action) => ({ kind: 'pure', action });
const MIX  = (agg, pas) => ({ kind: 'mixed', aggressive: agg, passive: pas });

// ---------------------- Solid / pure actions ------------------------------

test('cellFill: pure call returns the solid call color (no gradient, no outline)', () => {
  const r = cellFill(PAL, PURE('call'));
  assert.equal(r.background, '#38B359');
  assert.equal(r.outline, false);
  assert.equal(r.fg, foregroundOn('#38B359'));
});

test('cellFill: pure 3bet returns the solid 3bet color', () => {
  const r = cellFill(PAL, PURE('3bet'));
  assert.equal(r.background, '#EB4D4D');
  assert.equal(r.outline, false);
});

test('cellFill: pure fold uses palette.fold', () => {
  const r = cellFill(PAL, PURE('fold'));
  assert.equal(r.background, '#E5E5EA');
  assert.equal(r.outline, false);
});

test('cellFill: null action falls back to fold color', () => {
  const r = cellFill(PAL, null);
  assert.equal(r.background, '#E5E5EA');
  assert.equal(r.outline, false);
});

test('cellFill: fold=null resolves against auto fold gray', () => {
  const r = cellFill({ ...PAL, fold: null }, PURE('fold'));
  assert.equal(r.background, resolveAutoFoldColor());
  assert.equal(r.outline, false);
});

// ---------------------- Mixed actions / split cells -----------------------

test('cellFill: 3-Bet/Call → 50/50 gradient of 3bet red and call green', () => {
  const r = cellFill(PAL, MIX('3bet', 'call'));
  assert.equal(
    r.background,
    'linear-gradient(to right, #EB4D4D 50%, #38B359 50%)',
  );
});

test('cellFill: 3-Bet/Fold uses the pure fold color on the right half (not any mixed slot)', () => {
  const r = cellFill(PAL, MIX('3bet', 'fold'));
  assert.equal(
    r.background,
    'linear-gradient(to right, #EB4D4D 50%, #E5E5EA 50%)',
  );
});

test('cellFill: 3-Bet/Fold with fold=null uses the auto fold gray on the right half', () => {
  const r = cellFill({ ...PAL, fold: null }, MIX('3bet', 'fold'));
  assert.equal(
    r.background,
    `linear-gradient(to right, #EB4D4D 50%, ${resolveAutoFoldColor()} 50%)`,
  );
});

test('cellFill: 4-Bet/Call and All-In/Call use pure 4bet/5bet left, pure call right', () => {
  const r4 = cellFill(PAL, MIX('4bet', 'call'));
  assert.equal(
    r4.background,
    'linear-gradient(to right, #EB4D4D 50%, #38B359 50%)',
  );
  const r5 = cellFill(PAL, MIX('5bet', 'call'));
  assert.equal(
    r5.background,
    'linear-gradient(to right, #EB4D4D 50%, #38B359 50%)',
  );
});

// ---------------------- Text color rule (AC17.4) --------------------------

test('cellFill: 3-Bet/Call — both halves want white → fg white, no outline', () => {
  // #EB4D4D luminance ≈ 0.49 < 0.6 → white; #38B359 luminance ≈ 0.52 → white.
  const r = cellFill(PAL, MIX('3bet', 'call'));
  assert.equal(r.fg, '#ffffff');
  assert.equal(r.outline, false);
});

test('cellFill: 3-Bet/Fold with light fold — halves disagree → white text with outline', () => {
  // #EB4D4D → white; #E5E5EA (light fold) luminance ≈ 0.9 → dark text.
  const r = cellFill(PAL, MIX('3bet', 'fold'));
  assert.equal(r.fg, '#ffffff');
  assert.equal(r.outline, true);
});

test('cellFill: pure cells never request an outline', () => {
  for (const a of ['fold', 'call', 'open', '3bet', '4bet', '5bet']) {
    const r = cellFill(PAL, PURE(a));
    assert.equal(r.outline, false, `pure ${a} should not request outline`);
  }
});

// ---------------------- Legacy helper is still exported -------------------

test('colorForChartAction is still exported and still returns a single color', () => {
  assert.equal(colorForChartAction(PAL, PURE('call')), '#38B359');
  // The legacy value for mixed slots stays in the palette, even though
  // F17 no longer uses it to paint cells.
  assert.equal(colorForChartAction(PAL, MIX('3bet', 'call')), PAL['3betCall']);
});
