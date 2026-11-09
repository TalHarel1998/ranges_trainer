// Pure flop evaluation for the BB-vs-SB c-bet raise drill (F19).
//
// No DOM access; importable from Node. See web/SPEC.md §F19 for the
// acceptance criteria this module implements. The companion UI lives in
// app.js.
//
// Card model: { rank: 'A'|'K'|'Q'|'J'|'T'|'9'|'8'|'7'|'6'|'5'|'4'|'3'|'2',
//               suit: 's'|'h'|'d'|'c' }.

import { chartAction } from './domain.js';

export const RANKS = Object.freeze(['A','K','Q','J','T','9','8','7','6','5','4','3','2']);
export const SUITS = Object.freeze(['s','h','d','c']);

// A..2 index. Only used to pick the high card of a non-pair for the
// standard hand-class symbol ("AKs" not "KAs").
const RANK_INDEX = Object.freeze(Object.fromEntries(RANKS.map((r, i) => [r, i])));

// AC19.4-19.8: the ten 5-rank straight windows, A low (wheel) and A high.
export const STRAIGHT_WINDOWS = Object.freeze([
  ['A','2','3','4','5'],
  ['2','3','4','5','6'],
  ['3','4','5','6','7'],
  ['4','5','6','7','8'],
  ['5','6','7','8','9'],
  ['6','7','8','9','T'],
  ['7','8','9','T','J'],
  ['8','9','T','J','Q'],
  ['9','T','J','Q','K'],
  ['T','J','Q','K','A'],
].map(w => Object.freeze(w)));

export function fullDeck() {
  const deck = [];
  for (const r of RANKS) for (const s of SUITS) deck.push({ rank: r, suit: s });
  return deck;
}

export function cardKey(c) { return c.rank + c.suit; }

export function cardsEqual(a, b) { return a.rank === b.rank && a.suit === b.suit; }

// Hand-class symbol for two cards: 'AA', 'AKs', 'AKo'. Case-sensitive.
export function handClassOf(c1, c2) {
  if (c1.rank === c2.rank) return c1.rank + c2.rank;
  const i1 = RANK_INDEX[c1.rank], i2 = RANK_INDEX[c2.rank];
  const hi = i1 < i2 ? c1.rank : c2.rank;
  const lo = i1 < i2 ? c2.rank : c1.rank;
  return hi + lo + (c1.suit === c2.suit ? 's' : 'o');
}

// Pick a uniformly random card from `deck` using rng(). Returns the card
// and the deck without it. Pure (does not mutate the input array).
function drawFrom(deck, rng) {
  const idx = Math.floor(rng() * deck.length);
  const card = deck[idx];
  const rest = deck.slice(0, idx).concat(deck.slice(idx + 1));
  return { card, rest };
}

// AC19.1: BB continues vs an SB open with pure call or any mixed action.
// Pure 3-bet and pure fold are skipped so the drill never asks about a hand
// that the chart folds or 3-bets preflop.
function isContinueAction(ca) {
  if (!ca) return false;
  if (ca.kind === 'pure') return ca.action === 'call';
  if (ca.kind === 'mixed') return true;
  return false;
}

/**
 * Deal a drill hand per AC19.1–19.3.
 *
 * - Hero: 2 cards drawn uniformly from the 52-card deck, redrawn until the
 *   hand class is one the BB continues with in `chart`. Combo weighting
 *   emerges naturally because each specific 2-card combo has probability
 *   1 / C(52,2) of being drawn in each loop iteration.
 * - Flop: 3 more cards from the remaining 50. All 5 cards distinct.
 * - rng: () => float in [0, 1). Default Math.random; tests inject a
 *   seeded PRNG for determinism.
 *
 * Returns { hero: [c1, c2], board: [c3, c4, c5], handClass }.
 */
export function dealDrillHand(chart, rng = Math.random) {
  // Cap retries defensively so a buggy chart (empty continuing range)
  // can't loop forever. 1326 combos * 10 is more than enough headroom
  // against the real chart (hundreds of continuing combos).
  for (let attempts = 0; attempts < 13260; attempts++) {
    let deck = fullDeck();
    const d1 = drawFrom(deck, rng); deck = d1.rest;
    const d2 = drawFrom(deck, rng); deck = d2.rest;
    const cls = handClassOf(d1.card, d2.card);
    if (!isContinueAction(chartAction(chart, cls))) continue;
    const b1 = drawFrom(deck, rng); deck = b1.rest;
    const b2 = drawFrom(deck, rng); deck = b2.rest;
    const b3 = drawFrom(deck, rng); deck = b3.rest;
    return { hero: [d1.card, d2.card], board: [b1.card, b2.card, b3.card], handClass: cls };
  }
  throw new Error('dealDrillHand: no continuing hand class found in chart');
}

// --- Evaluation ---------------------------------------------------------

// AC19.6: W contains a rank held by a hole card that is not on B. The two
// hole cards and the three board cards are always distinct, so this test
// is about rank membership, not card identity.
function heroContributes(window, holeRanks, boardRankSet) {
  for (const r of holeRanks) {
    if (!window.includes(r)) continue;
    if (boardRankSet.has(r)) continue;
    return true;
  }
  return false;
}

/**
 * Evaluate the simplified BB raising rule per AC19.4–19.11.
 *
 * @param {{rank:string,suit:string}[]} hole 2-card hand (hero)
 * @param {{rank:string,suit:string}[]} board 3-card flop
 * @returns {{
 *   answer: 'raise'|'noRaise',
 *   rule: 1|2|3|4|5,
 *   made: 'twoPairPlus'|'pair'|'noPair',
 *   draws: { fdFlush: boolean, fdStraight: boolean,
 *            bdFlush: boolean, bdStraight: boolean }
 * }}
 */
export function evaluateCbetRaise(hole, board) {
  if (!Array.isArray(hole)  || hole.length  !== 2) throw new Error('hole must be exactly 2 cards');
  if (!Array.isArray(board) || board.length !== 3) throw new Error('board must be exactly 3 cards');

  const holeRanks  = hole.map(c => c.rank);
  const boardRanks = board.map(c => c.rank);
  const unionRanks = new Set([...holeRanks, ...boardRanks]);
  const boardRankSet = new Set(boardRanks);

  // Rank counts across H∪B (for sets/trips/full houses/quads).
  const rankCount = new Map();
  for (const r of [...holeRanks, ...boardRanks]) {
    rankCount.set(r, (rankCount.get(r) || 0) + 1);
  }
  const holeHasRank = (r) => holeRanks.includes(r);

  // Suit counts across H∪B (for made flush + flush draws).
  const suitCount = new Map();
  for (const c of [...hole, ...board]) suitCount.set(c.suit, (suitCount.get(c.suit) || 0) + 1);

  // --- AC19.5: two pair or better (hero-made) --------------------------

  // Flush: 5 cards of one suit. With 2 hole + 3 board, this can only
  // happen when the flop is monotone and both hole cards match the suit,
  // which always has hero contribution.
  const madeFlush = [...suitCount.values()].some(n => n >= 5);

  // Set / trips / full house / quads: some rank appears ≥3 times across
  // H∪B AND at least one hole card has that rank. Covers full houses
  // and quads too (they imply a set of trips including hero).
  let setOrTrips = false;
  for (const [r, n] of rankCount) {
    if (n >= 3 && holeHasRank(r)) { setOrTrips = true; break; }
  }

  // Two pair: the two hole cards have different ranks AND both ranks are
  // on the board. "A paired board plus one hero pair is one pair, not two
  // pair" falls out of this rule because the two hole ranks must differ.
  const twoPair = holeRanks[0] !== holeRanks[1]
    && boardRankSet.has(holeRanks[0])
    && boardRankSet.has(holeRanks[1]);

  // Straight: a 5-rank window fully covered by H∪B ranks with hero
  // contribution. Board-only straights are intentionally excluded.
  const madeStraight = STRAIGHT_WINDOWS.some(w =>
    w.every(r => unionRanks.has(r)) && heroContributes(w, holeRanks, boardRankSet)
  );

  const twoPairPlus = madeFlush || setOrTrips || twoPair || madeStraight;

  // --- AC19.4: one hero pair ------------------------------------------
  // Pocket pair OR a hole-card rank appears on the board. A board-only
  // pair (e.g. 77 of hole on K-K-6) remains a single hero pair because
  // the hole-card rank still provides the primary pair.
  const pocketPair = holeRanks[0] === holeRanks[1];
  const heroPair = pocketPair
    || boardRankSet.has(holeRanks[0])
    || boardRankSet.has(holeRanks[1]);

  let made;
  if (twoPairPlus) made = 'twoPairPlus';
  else if (heroPair) made = 'pair';
  else made = 'noPair';

  // --- AC19.9: flush draws --------------------------------------------
  let fdFlush = false, bdFlush = false;
  for (const [suit, n] of suitCount) {
    // "At least one of them a hole card" — hero must contribute to the suit.
    if (!hole.some(c => c.suit === suit)) continue;
    if (n === 4) fdFlush = true;
    else if (n === 3) bdFlush = true;
  }

  // --- AC19.7/19.8: straight draws, evaluated per window ---------------
  // bd is evaluated independently of fd (per AC19.8). We only short-circuit
  // when the hand already has a made straight (AC19.7 requires "no made
  // straight" for a fd straight draw; bd is implicitly moot too).
  let fdStraight = false, bdStraight = false;
  if (!madeStraight) {
    for (const w of STRAIGHT_WINDOWS) {
      let missing = 0;
      for (const r of w) if (!unionRanks.has(r)) missing++;
      if (missing !== 1 && missing !== 2) continue;
      if (!heroContributes(w, holeRanks, boardRankSet)) continue;
      if (missing === 1) fdStraight = true;
      else bdStraight = true;
    }
  }

  const draws = { fdFlush, fdStraight, bdFlush, bdStraight };

  // --- AC19.10: decision --------------------------------------------
  const anyDraw   = fdFlush || fdStraight || bdFlush || bdStraight;
  const anyFdDraw = fdFlush || fdStraight;

  let rule, answer;
  if (twoPairPlus) {
    rule = 1; answer = 'raise';
  } else if (heroPair && !anyDraw) {
    rule = 2; answer = 'raise';
  } else if (heroPair) {
    rule = 3; answer = 'noRaise';
  } else if (bdFlush && bdStraight && !anyFdDraw) {
    rule = 4; answer = 'raise';
  } else {
    rule = 5; answer = 'noRaise';
  }

  return { answer, rule, made, draws };
}

// --- Description -------------------------------------------------------

/**
 * Short descriptive text for the drill UI.
 *   handDesc: "Pair · backdoor straight" style, listing the made hand
 *             (Two pair+ / Pair / No pair) and every draw present.
 *   reason:   the AC19.10 reason text for the rule that fired.
 *
 * Rule 5 has no reason text spelled out in AC19.10. The parenthetical
 * ("no pair: has a frontdoor draw, or lacks one of the two backdoors")
 * describes the catch-all case, so the reason text summarises that.
 */
export function describeHand(result) {
  const parts = [];
  if (result.made === 'twoPairPlus') parts.push('Two pair+');
  else if (result.made === 'pair') parts.push('Pair');
  else parts.push('No pair');
  if (result.draws.fdFlush)    parts.push('frontdoor flush');
  if (result.draws.fdStraight) parts.push('frontdoor straight');
  if (result.draws.bdFlush)    parts.push('backdoor flush');
  if (result.draws.bdStraight) parts.push('backdoor straight');
  const handDesc = parts.join(' · ');

  let reason;
  switch (result.rule) {
    case 1: reason = 'Two pair or better — always raise'; break;
    case 2: reason = 'Pair with no draws — hates a turn barrel'; break;
    case 3: reason = 'Pair with a draw — call'; break;
    case 4: reason = 'Double backdoor bluff'; break;
    case 5: reason = result.made === 'noPair' && (result.draws.fdFlush || result.draws.fdStraight)
      ? 'No pair with a frontdoor draw — just call'
      : 'No pair, not a double backdoor — just call';
      break;
    default: reason = '';
  }
  return { handDesc, reason };
}
