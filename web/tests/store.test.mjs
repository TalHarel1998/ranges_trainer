// Tests for the pure reconcilePendingWrites logic.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { reconcilePendingWrites } from '../js/store.js';

const TTL = 30 * 60 * 1000;

test('reconcile: empty inputs → empty outputs', () => {
  const r = reconcilePendingWrites({}, {}, 1_000_000);
  assert.deepEqual(r.pending, {});
  assert.deepEqual(r.overrides, {});
});

test('reconcile: fresh pending with no deployed yet → keep and override', () => {
  const now = 1_000_000;
  const pending = { 'charts/rfi/utg.json': { text: 'NEW', savedAt: now - 60_000 } };
  const r = reconcilePendingWrites(pending, {}, now, TTL);
  assert.deepEqual(r.overrides, { 'charts/rfi/utg.json': 'NEW' });
  assert.deepEqual(r.pending, pending);
});

test('reconcile: stale pending (older than TTL) → drop', () => {
  const now = 1_000_000;
  const pending = { 'charts/rfi/utg.json': { text: 'OLD', savedAt: now - TTL - 1 } };
  const r = reconcilePendingWrites(pending, { 'charts/rfi/utg.json': 'DEPLOYED' }, now, TTL);
  assert.deepEqual(r.overrides, {});
  assert.deepEqual(r.pending, {});
});

test('reconcile: deployed equals pending → drop (deployment caught up)', () => {
  const now = 1_000_000;
  const pending = { 'charts/rfi/utg.json': { text: 'SAME', savedAt: now - 60_000 } };
  const r = reconcilePendingWrites(pending, { 'charts/rfi/utg.json': 'SAME' }, now, TTL);
  assert.deepEqual(r.overrides, {});
  assert.deepEqual(r.pending, {});
});

test('reconcile: deployed differs and fresh → keep and override', () => {
  const now = 1_000_000;
  const pending = { 'charts/rfi/utg.json': { text: 'NEW', savedAt: now - 60_000 } };
  const r = reconcilePendingWrites(pending, { 'charts/rfi/utg.json': 'OLD' }, now, TTL);
  assert.deepEqual(r.overrides, { 'charts/rfi/utg.json': 'NEW' });
  assert.deepEqual(r.pending, pending);
});

test('reconcile: applies independently per path', () => {
  const now = 1_000_000;
  const pending = {
    'charts/rfi/utg.json': { text: 'A', savedAt: now - 60_000 },  // fresh, differs → keep
    'palette.json':         { text: 'B', savedAt: now - TTL - 1 },// stale → drop
    'charts/rfi/mp.json':   { text: 'C', savedAt: now - 60_000 },  // caught up → drop
  };
  const deployed = {
    'charts/rfi/utg.json': 'A-old',
    'palette.json':         'B-old',
    'charts/rfi/mp.json':   'C',
  };
  const r = reconcilePendingWrites(pending, deployed, now, TTL);
  assert.deepEqual(r.overrides, { 'charts/rfi/utg.json': 'A' });
  assert.deepEqual(r.pending, { 'charts/rfi/utg.json': pending['charts/rfi/utg.json'] });
});

test('reconcile: malformed entries are ignored', () => {
  const now = 1_000_000;
  const pending = {
    'ok':         { text: 'ok',   savedAt: now - 1000 },
    'noText':     { savedAt: now - 1000 },
    'noSavedAt':  { text: 'x' },
    'badSavedAt': { text: 'x', savedAt: 'nope' },
    'nullEntry':  null,
    'notObject':  'string',
  };
  const r = reconcilePendingWrites(pending, {}, now, TTL);
  assert.deepEqual(r.overrides, { ok: 'ok' });
  assert.deepEqual(r.pending, { ok: pending.ok });
});

test('reconcile: unknown deployed values keep fresh pending (treated as "not caught up")', () => {
  const now = 1_000_000;
  const pending = { 'charts/rfi/utg.json': { text: 'NEW', savedAt: now - 1000 } };
  const r = reconcilePendingWrites(pending, { 'other': 'x' }, now, TTL);
  assert.deepEqual(r.overrides, { 'charts/rfi/utg.json': 'NEW' });
});

test('reconcile: boundary — exactly ttl old is still kept', () => {
  const now = 1_000_000;
  const pending = { p: { text: 'x', savedAt: now - TTL } }; // not yet "> ttl"
  const r = reconcilePendingWrites(pending, {}, now, TTL);
  assert.deepEqual(r.overrides, { p: 'x' });
});
