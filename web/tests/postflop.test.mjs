// Node tests for the pure flop drill module (F19).
//
// Covers every AC19.x reference case and dealer invariants. The 6♥5♥
// annotation in AC19.12 contradicts AC19.8 — see the test comment and
// SPEC_AMBIGUITY block below for the resolution.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { buildChart, chartAction } from '../js/domain.js';
import {
  evaluateCbetRaise, dealDrillHand, describeHand,
  handClassOf, fullDeck, STRAIGHT_WINDOWS, RANKS, SUITS,
} from '../js/postflop.js';

const __filename = fileURLToPath(import.meta.url);
const WEB_DIR = path.resolve(path.dirname(__filename), '..');

async function loadBbVsSb() {
  const text = await readFile(path.join(WEB_DIR, 'charts/defense/bb_vs_sb.json'), 'utf8');
  return buildChart(JSON.parse(text));
}

// Deterministic 32-bit PRNG for test determinism. mulberry32.
function mulberry32(seed) {
  let a = (seed >>> 0);
  return function rng() {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Convenience: turn "Kd Qd 6c" style strings into card objects.
function C(spec) {
  // "Kd" → { rank: 'K', suit: 'd' }
  return { rank: spec[0], suit: spec[1] };
}
function H(a, b) { return [C(a), C(b)]; }
function Board(a, b, c) { return [C(a), C(b), C(c)]; }

// ---------------- shape & constants ----------------

test('STRAIGHT_WINDOWS: 10 windows of 5 ranks each, A2345..TJQKA', () => {
  assert.equal(STRAIGHT_WINDOWS.length, 10);
  for (const w of STRAIGHT_WINDOWS) assert.equal(w.length, 5);
  assert.deepEqual([...STRAIGHT_WINDOWS[0]], ['A','2','3','4','5']);
  assert.deepEqual([...STRAIGHT_WINDOWS[9]], ['T','J','Q','K','A']);
});

test('fullDeck produces 52 unique cards', () => {
  const deck = fullDeck();
  assert.equal(deck.length, 52);
  const keys = new Set(deck.map(c => c.rank + c.suit));
  assert.equal(keys.size, 52);
  for (const r of RANKS) for (const s of SUITS) assert.ok(keys.has(r + s));
});

test('handClassOf: pair / suited / offsuit with high rank first', () => {
  assert.equal(handClassOf(C('As'), C('Ah')), 'AA');
  assert.equal(handClassOf(C('As'), C('Ks')), 'AKs');
  assert.equal(handClassOf(C('Kd'), C('Ac')), 'AKo'); // reorder
  assert.equal(handClassOf(C('7c'), C('2s')), '72o');
});

// ---------------- AC19.12 reference cases ----------------
// Board K♦Q♦6♣ for the first 9 cases.

const B_KQ6 = Board('Kd','Qd','6c');

test('AC19.12: K♠7♠ on K♦Q♦6♣ → raise (pair, no draws)', () => {
  const r = evaluateCbetRaise(H('Ks','7s'), B_KQ6);
  assert.equal(r.answer, 'raise');
  assert.equal(r.rule, 2);
  assert.equal(r.made, 'pair');
  assert.deepEqual(r.draws, { fdFlush: false, fdStraight: false, bdFlush: false, bdStraight: false });
});

test('AC19.12: A♠K♣ on K♦Q♦6♣ → noRaise (pair + bd straight)', () => {
  const r = evaluateCbetRaise(H('As','Kc'), B_KQ6);
  assert.equal(r.answer, 'noRaise');
  assert.equal(r.rule, 3);
  assert.equal(r.made, 'pair');
  assert.equal(r.draws.bdStraight, true);  // TJQKA covered by A/K/Q, hero A contributes
  assert.equal(r.draws.fdStraight, false);
  assert.equal(r.draws.fdFlush, false);
  assert.equal(r.draws.bdFlush, false);
});

// SPEC_AMBIGUITY: AC19.12 lists "6♥5♥ no raise (pair + bd straight)". Under
// AC19.8 strict ("some window W misses exactly 2 ranks of H∪B ranks, with
// hero contribution"), 6♥5♥ on K♦Q♦6♣ has no 5-rank window covering 3 of
// H∪B's ranks: H∪B rank set is {5, 6, Q, K}, and no 5-consecutive window
// contains 3 of those (5 and 6 are adjacent; Q and K are adjacent; the two
// clusters are 6+ ranks apart). Equivalently, the hand needs at least 3
// running cards to make any straight, which is beyond "backdoor" by any
// poker-literal definition. 2♠2♥ demonstrates that the alternative
// multiset reading overshoots: it would classify 2♠2♥ as pair + bd
// straight (via window 23456 catching the pair plus the board's 6),
// contradicting its own AC19.12 annotation "pair, no draws → raise". The
// author's "pair + bd straight" annotation on 6♥5♥ is therefore the
// outlier. Resolution: implement AC19.8 strictly; the hand reduces to
// pair with no draws → rule 2 → raise.
test('AC19.12: 6♥5♥ on K♦Q♦6♣ → raise (strict AC19.8; spec said noRaise — see SPEC_AMBIGUITY)', () => {
  const r = evaluateCbetRaise(H('6h','5h'), B_KQ6);
  assert.equal(r.answer, 'raise');
  assert.equal(r.rule, 2);
  assert.equal(r.made, 'pair');
  assert.equal(r.draws.bdStraight, false);
  assert.equal(r.draws.fdStraight, false);
});

test('AC19.12: 9♣8♣ on K♦Q♦6♣ → raise (bd flush + bd straight, no pair)', () => {
  const r = evaluateCbetRaise(H('9c','8c'), B_KQ6);
  assert.equal(r.answer, 'raise');
  assert.equal(r.rule, 4);
  assert.equal(r.made, 'noPair');
  assert.equal(r.draws.bdFlush, true);     // three clubs: 9c, 8c, 6c
  assert.equal(r.draws.bdStraight, true);  // 56789 / 6789T / 89TJQ / 9TJQK all qualify
  assert.equal(r.draws.fdFlush, false);
  assert.equal(r.draws.fdStraight, false);
});

test('AC19.12: J♥T♥ on K♦Q♦6♣ → noRaise (OESD = frontdoor straight)', () => {
  const r = evaluateCbetRaise(H('Jh','Th'), B_KQ6);
  assert.equal(r.answer, 'noRaise');
  assert.equal(r.rule, 5);
  assert.equal(r.made, 'noPair');
  assert.equal(r.draws.fdStraight, true);  // 9TJQK or TJQKA each missing 1
  assert.equal(r.draws.fdFlush, false);
});

test('AC19.12: A♦5♦ on K♦Q♦6♣ → noRaise (fd flush)', () => {
  const r = evaluateCbetRaise(H('Ad','5d'), B_KQ6);
  assert.equal(r.answer, 'noRaise');
  assert.equal(r.rule, 5);
  assert.equal(r.made, 'noPair');
  assert.equal(r.draws.fdFlush, true);  // four diamonds total
  assert.equal(r.draws.fdStraight, false);
});

test('AC19.12: 2♠2♥ on K♦Q♦6♣ → raise (pair, no draws)', () => {
  const r = evaluateCbetRaise(H('2s','2h'), B_KQ6);
  assert.equal(r.answer, 'raise');
  assert.equal(r.rule, 2);
  assert.equal(r.made, 'pair');
  assert.deepEqual(r.draws, { fdFlush: false, fdStraight: false, bdFlush: false, bdStraight: false });
});

test('AC19.12: K♣Q♠ on K♦Q♦6♣ → raise (two pair)', () => {
  const r = evaluateCbetRaise(H('Kc','Qs'), B_KQ6);
  assert.equal(r.answer, 'raise');
  assert.equal(r.rule, 1);
  assert.equal(r.made, 'twoPairPlus');
});

test('AC19.12: 6♠6♥ on K♦Q♦6♣ → raise (set)', () => {
  const r = evaluateCbetRaise(H('6s','6h'), B_KQ6);
  assert.equal(r.answer, 'raise');
  assert.equal(r.rule, 1);
  assert.equal(r.made, 'twoPairPlus');
});

// Supplementary AC19.12 cases

test('AC19.12: A♥5♣ on K♠K♣6♦ = no pair', () => {
  const r = evaluateCbetRaise(H('Ah','5c'), Board('Ks','Kc','6d'));
  assert.equal(r.made, 'noPair');
});

test('AC19.12: 7♠7♥ on K♠K♦6♣ = one pair (paired board does not promote to two pair)', () => {
  const r = evaluateCbetRaise(H('7s','7h'), Board('Ks','Kd','6c'));
  assert.equal(r.made, 'pair');
});

test('AC19.12: A♥2♥ on 9♠8♦7♣ — T/J backdoor straight (needs no hole card) must NOT count', () => {
  // H∪B ranks {A, 2, 7, 8, 9}. Windows 56789, 6789T, 789TJ each miss 2
  // ranks of H∪B, but hero's A and 2 are not in any of them, so hero
  // contributes nothing.
  const r = evaluateCbetRaise(H('Ah','2h'), Board('9s','8d','7c'));
  assert.equal(r.made, 'noPair');
  assert.equal(r.draws.bdStraight, false);
  assert.equal(r.draws.fdStraight, false);
  assert.equal(r.draws.fdFlush, false);
  assert.equal(r.draws.bdFlush, false);
});

test('AC19.12: A♠2♠ on 4♦5♣K♥ = frontdoor (wheel gutshot)', () => {
  // A2345 window is covered by A, 2 (hole) + 4, 5 (board); missing 3 only.
  const r = evaluateCbetRaise(H('As','2s'), Board('4d','5c','Kh'));
  assert.equal(r.made, 'noPair');
  assert.equal(r.draws.fdStraight, true);
  assert.equal(r.answer, 'noRaise');
});

test('AC19.12: flush made with two suited hole cards on a monotone flop = two pair+', () => {
  // Hero A♦K♦ on 2♦3♦4♦: five diamonds → made flush. Classed as
  // twoPairPlus even though hero also has a straight.
  const r = evaluateCbetRaise(H('Ad','Kd'), Board('2d','3d','4d'));
  assert.equal(r.made, 'twoPairPlus');
  assert.equal(r.answer, 'raise');
  assert.equal(r.rule, 1);
});

// ---------------- Describe helper ----------------

test('describeHand produces "Pair · backdoor straight" style text and the AC19.10 reason', () => {
  const r = evaluateCbetRaise(H('As','Kc'), B_KQ6);
  const { handDesc, reason } = describeHand(r);
  assert.equal(handDesc, 'Pair · backdoor straight');
  assert.equal(reason, 'Pair with backdoors');
});

test('describeHand: rule-1 and rule-2 reasons match AC19.10 wording', () => {
  const set = describeHand(evaluateCbetRaise(H('6s','6h'), B_KQ6));
  assert.equal(set.reason, 'Two pair or better');
  assert.equal(set.handDesc, 'Two pair+');
  const pairDry = describeHand(evaluateCbetRaise(H('Ks','7s'), B_KQ6));
  assert.equal(pairDry.reason, 'Pair with no backdoors');
  assert.equal(pairDry.handDesc, 'Pair');
});

test('describeHand: rule-4 double backdoor and rule-5 catch-all', () => {
  const dbd = describeHand(evaluateCbetRaise(H('9c','8c'), B_KQ6));
  assert.equal(dbd.reason, 'Double backdoor');
  const sd = describeHand(evaluateCbetRaise(H('Jh','Th'), B_KQ6));
  assert.equal(sd.reason, 'Straight draw');
  const fd = describeHand(evaluateCbetRaise(H('Ad','2d'), B_KQ6));
  assert.equal(fd.reason, 'Flush draw');
  const both = describeHand(evaluateCbetRaise(H('Jd','Td'), B_KQ6));
  assert.equal(both.reason, 'Flush and straight draw');
  const none = describeHand(evaluateCbetRaise(H('9h','8c'), B_KQ6));
  assert.equal(none.reason, 'No raise combo');
});

// ---------------- Each of the 5 rules hit at least once ----------------

test('each of the 5 rules in AC19.10 is reachable by a deterministic case', () => {
  const hits = new Set();
  for (const [hole, board] of [
    [H('6s','6h'), B_KQ6],                           // rule 1 (set)
    [H('Ks','7s'), B_KQ6],                           // rule 2 (pair, no draws)
    [H('As','Kc'), B_KQ6],                           // rule 3 (pair + draw)
    [H('9c','8c'), B_KQ6],                           // rule 4 (double backdoor)
    [H('Jh','Th'), B_KQ6],                           // rule 5 (no pair + fd)
  ]) {
    hits.add(evaluateCbetRaise(hole, board).rule);
  }
  assert.deepEqual([...hits].sort(), [1, 2, 3, 4, 5]);
});

// ---------------- Contribution-rule edge cases ----------------

test('contribution: window missing 2 ranks but no hole rank in window → not a bd straight', () => {
  // Hole 7♣2♠ on 7♦9♥T♦.
  // Window 6789T covers 7, 9, T → missing 2 ranks (6, 8). Hero rank 7 is
  // on B so does not contribute; hero rank 2 is not in the window. No
  // hero contribution → not a bd straight.
  const r = evaluateCbetRaise(H('7c','2s'), Board('7d','9h','Td'));
  assert.equal(r.made, 'pair');
  assert.equal(r.draws.bdStraight, false);
  assert.equal(r.draws.fdStraight, false);
  assert.equal(r.rule, 2);
  assert.equal(r.answer, 'raise');
});

test('contribution: hole-rank on board does not count toward a straight window', () => {
  // Hole K♠7♣, board K♦9♦8♥. Windows 56789/6789T/789TJ cover 7,8,9 — but
  // hero's 7 is NOT on B, so 7 contributes. 8,9 would, but only after
  // intersecting a window with the hole rank. Verify explicitly: K is on B
  // so does not grant contribution via its presence in 9TJQK/TJQKA.
  const r = evaluateCbetRaise(H('Ks','7c'), Board('Kd','9d','8h'));
  // The 7 contributes to 56789/6789T/789TJ (bd via some, fd via none).
  assert.equal(r.made, 'pair');
  // 56789: covers 7, 8, 9 → missing 5, 6 (2) → bd. Contribution via 7.
  assert.equal(r.draws.bdStraight, true);
  // TJQKA / 9TJQK contain K (hero holds K, but K is on B). Window TJQKA
  // covers K only from H∪B (plus nothing else), 4 missing — not a draw.
  // The hand is pair + bd straight → rule 3.
  assert.equal(r.rule, 3);
});

test('contribution: pocket pair alone cannot produce a bd straight on a disconnected board', () => {
  // 2♠2♥ on K♦Q♦6♣: H∪B ranks {2, 6, Q, K}. No 5-rank window contains 3
  // of {2, 6, Q, K} (the clusters are 4+ ranks apart). No bd draw.
  const r = evaluateCbetRaise(H('2s','2h'), B_KQ6);
  assert.equal(r.draws.bdStraight, false);
});

test('contribution: made straight suppresses straight draws from being flagged', () => {
  // Hero QJ on T 9 8: straight 8-9-T-J-Q. Draw flags must be clear.
  const r = evaluateCbetRaise(H('Qs','Jc'), Board('Td','9d','8c'));
  assert.equal(r.made, 'twoPairPlus');
  assert.equal(r.draws.fdStraight, false);
  assert.equal(r.draws.bdStraight, false);
  assert.equal(r.rule, 1);
});

// ---------------- Dealer invariants ----------------

test('dealDrillHand (10,000 seeded deals): never deals a pure-3bet or fold class', async () => {
  const chart = await loadBbVsSb();
  const rng = mulberry32(0xC0FFEE);
  for (let i = 0; i < 10000; i++) {
    const deal = dealDrillHand(chart, rng);
    const ca = chartAction(chart, deal.handClass);
    const isPure3b = ca.kind === 'pure' && ca.action === '3bet';
    const isFold   = ca.kind === 'pure' && ca.action === 'fold';
    assert.ok(!isPure3b, `deal #${i} ${deal.handClass} is pure 3bet`);
    assert.ok(!isFold,   `deal #${i} ${deal.handClass} is fold`);
  }
});

test('dealDrillHand: all 5 cards distinct', async () => {
  const chart = await loadBbVsSb();
  const rng = mulberry32(0xBEEF);
  for (let i = 0; i < 500; i++) {
    const d = dealDrillHand(chart, rng);
    const keys = new Set([...d.hero, ...d.board].map(c => c.rank + c.suit));
    assert.equal(keys.size, 5, `deal #${i} has duplicate card`);
  }
});

test('dealDrillHand: flop never contains either hole card', async () => {
  const chart = await loadBbVsSb();
  const rng = mulberry32(0x1234);
  for (let i = 0; i < 500; i++) {
    const d = dealDrillHand(chart, rng);
    const holeKeys = new Set(d.hero.map(c => c.rank + c.suit));
    for (const b of d.board) {
      assert.ok(!holeKeys.has(b.rank + b.suit),
        `deal #${i} board ${b.rank + b.suit} collides with hero`);
    }
  }
});

test('dealDrillHand: combo-weighted — offsuit continuing class dealt roughly 2× pocket pair class', async () => {
  // 88 (6 combos, mixed-call) vs A5o (12 combos, mixed-call). Both are
  // continuing in bb_vs_sb. Expected ratio ≈ 2.0 over 10k deals.
  const chart = await loadBbVsSb();
  const rng = mulberry32(0xABCD);
  let p88 = 0, a5o = 0;
  for (let i = 0; i < 10000; i++) {
    const d = dealDrillHand(chart, rng);
    if (d.handClass === '88')  p88++;
    else if (d.handClass === 'A5o') a5o++;
  }
  assert.ok(p88 > 20, `expected a few 88 deals, got ${p88}`);
  assert.ok(a5o > p88, `expected A5o(${a5o}) > 88(${p88})`);
  const ratio = a5o / Math.max(1, p88);
  assert.ok(ratio > 1.3 && ratio < 3.5,
    `expected A5o/88 ratio near 2, got ${ratio.toFixed(2)} (p88=${p88}, a5o=${a5o})`);
});

test('dealDrillHand: aggregate pair-combos ≪ offsuit-combos (chart has far more offsuit continuing combos)', async () => {
  const chart = await loadBbVsSb();
  const rng = mulberry32(0xDEADBEEF);
  let pairs = 0, offsuit = 0, suited = 0;
  for (let i = 0; i < 5000; i++) {
    const cls = dealDrillHand(chart, rng).handClass;
    if (cls.length === 2) pairs++;
    else if (cls[2] === 'o') offsuit++;
    else suited++;
  }
  // bb_vs_sb continuing: ~42 pair combos vs ~336 offsuit vs ~272 suited.
  // Expect offsuit > suited > pairs by a healthy margin over 5k deals.
  assert.ok(offsuit > pairs * 3, `offsuit(${offsuit}) should dominate pairs(${pairs})`);
  assert.ok(suited > pairs * 2, `suited(${suited}) should dominate pairs(${pairs})`);
});
