// Node tests for the pure domain layer. Also exercises the on-disk chart
// JSONs via `fs` (bypassing the browser fetch loader) so parser + builder
// cover every real chart.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import {
  RANKS, POSITIONS, GRID_SIZE, TOTAL_COMBOS,
  parseHand, parseRange, RangeParseError,
  handAt, coordOf, allHands, handCombos, bothBlackCombos,
  parseScenarioKey, scenarioTitle, scenarioRowLabel,
  threeBettors, threeBettorGroupTitle,
  buildChart, chartAction, actionsEqual, actionContains,
  handClassCountContaining, comboCountContaining, fractionContaining,
  pureComboCountFor, mixedComboCount,
  gradeOne, gradeChart,
  unifiedRFI, recallPaletteFor,
  chartsForCategory, CATEGORIES, ChartDecodeError,
} from '../js/domain.js';

import { CHART_FILES } from '../js/charts.js';

const __filename = fileURLToPath(import.meta.url);
const WEB_DIR = path.resolve(path.dirname(__filename), '..');

async function loadChartFromDisk(relative) {
  const absolute = path.resolve(WEB_DIR, relative);
  const text = await readFile(absolute, 'utf8');
  return buildChart(JSON.parse(text));
}

async function loadAllChartsFromDisk() {
  return Promise.all(CHART_FILES.map(loadChartFromDisk));
}

// ---------------------- Hand classes & grid ----------------------

test('allHands produces 169 unique hand classes', () => {
  const hands = allHands();
  assert.equal(hands.length, 169);
  assert.equal(new Set(hands).size, 169);
});

test('combo counts: pair=6, suited=4, offsuit=12; totals = 1326', () => {
  assert.equal(handCombos('AA'), 6);
  assert.equal(handCombos('AKs'), 4);
  assert.equal(handCombos('AKo'), 12);
  let total = 0;
  for (const h of allHands()) total += handCombos(h);
  assert.equal(total, TOTAL_COMBOS);
});

test('bothBlackCombos: pair=1, suited=2, offsuit=2', () => {
  assert.equal(bothBlackCombos('AA'), 1);
  assert.equal(bothBlackCombos('AKs'), 2);
  assert.equal(bothBlackCombos('AKo'), 2);
});

test('grid coord: (0,0)=AA, (0,1)=AKs, (1,0)=AKo, (12,12)=22', () => {
  assert.equal(handAt(0, 0), 'AA');
  assert.equal(handAt(0, 1), 'AKs');
  assert.equal(handAt(1, 0), 'AKo');
  assert.equal(handAt(12, 12), '22');
  assert.deepEqual(coordOf('AKs'), { row: 0, col: 1 });
  assert.deepEqual(coordOf('AKo'), { row: 1, col: 0 });
  assert.deepEqual(coordOf('AA'),  { row: 0, col: 0 });
  // 72o: high=7 (idx 7), low=2 (idx 12). Offsuit → (lowIdx, highIdx).
  assert.deepEqual(coordOf('72o'), { row: 12, col: 7 });
});

test('parseHand accepts canonical symbols and rejects malformed', () => {
  assert.equal(parseHand('AA').symbol, 'AA');
  assert.equal(parseHand('aks').symbol, 'AKs');
  assert.equal(parseHand('KAo').symbol, 'AKo'); // reorders to high-first
  assert.equal(parseHand('AKS').symbol, 'AKs');
  assert.equal(parseHand('AKx'), null);
  assert.equal(parseHand('AA s'), null);
  assert.equal(parseHand('A'), null);
  assert.equal(parseHand('AKo5'), null);
  assert.equal(parseHand('AAs'), null); // pairs can't be suited
});

// ---------------------- Range string parser ----------------------

test('range parser: single tokens', () => {
  assert.deepEqual([...parseRange('AA')], ['AA']);
  assert.deepEqual([...parseRange('AKs')], ['AKs']);
  assert.deepEqual([...parseRange('AKo')], ['AKo']);
});

test('range parser: whitespace, case, empty', () => {
  assert.deepEqual([...parseRange('')], []);
  assert.deepEqual([...parseRange('   ')], []);
  assert.deepEqual([...parseRange('   AA  ')], ['AA']);
  const got = new Set(parseRange('aa, KK , qq'));
  assert.deepEqual([...got].sort(), ['AA','KK','QQ'].sort());
});

test('range parser: pair+', () => {
  const got = parseRange('22+');
  assert.equal(got.size, 13);
  for (const r of RANKS) assert.ok(got.has(r + r), `expected ${r + r}`);
  const sevens = parseRange('77+');
  assert.deepEqual([...sevens].sort(),
    ['AA','KK','QQ','JJ','TT','99','88','77'].sort());
});

test('range parser: suited+ and offsuit+', () => {
  const got = parseRange('A2s+');
  assert.equal(got.size, 12);
  assert.ok(got.has('A2s'));
  assert.ok(got.has('AKs'));
  assert.ok(!got.has('AA'));
  const kings = parseRange('K9o+');
  assert.deepEqual([...kings].sort(), ['K9o','KTo','KJo','KQo'].sort());
});

test('range parser rejects invalid tokens', () => {
  assert.throws(() => parseRange('A'), RangeParseError);
  assert.throws(() => parseRange('AX'), RangeParseError);
  assert.throws(() => parseRange('AKx'), RangeParseError);
  assert.throws(() => parseRange('A2s,ZZ'), RangeParseError);
});

test('range parser deduplicates across tokens', () => {
  const got = parseRange('AA, AA');
  assert.equal(got.size, 1);
});

// ---------------------- Scenario ----------------------

test('scenario key round-trip', () => {
  const cases = [
    ['rfi.utg',           { kind: 'rfi', hero: 'UTG' }],
    ['def.bb.vs.utg',     { kind: 'defense', hero: 'BB', villain: 'UTG' }],
    ['vs3b.utg.vs.ip',    { kind: 'vs3bet', hero: 'UTG', group: 'ip' }],
    ['vs4b.btn.vs.co',    { kind: 'vs4bet', hero: 'BTN', villain: 'CO' }],
  ];
  for (const [key, expected] of cases) {
    const sc = parseScenarioKey(key);
    assert.ok(sc, `parse ${key}`);
    for (const [k, v] of Object.entries(expected)) assert.equal(sc[k], v);
  }
  assert.equal(parseScenarioKey('garbage'), null);
  assert.equal(parseScenarioKey('rfi.foo'), null);
  assert.equal(parseScenarioKey('def.bb.vs.xx'), null);
});

test('threeBettors: UTG ip = MP,CO,BTN; UTG oop = SB,BB; CO ip = BTN', () => {
  assert.deepEqual(threeBettors('UTG', 'ip'), ['MP','CO','BTN']);
  assert.deepEqual(threeBettors('UTG', 'oop'), ['SB','BB']);
  assert.deepEqual(threeBettors('CO', 'ip'), ['BTN']);
  assert.deepEqual(threeBettors('CO', 'oop'), ['SB','BB']);
  assert.deepEqual(threeBettors('BTN', 'oop'), ['SB','BB']);
  assert.deepEqual(threeBettors('BTN', 'ip'), []);
  assert.deepEqual(threeBettors('SB', 'ip'), ['BB']);
  assert.deepEqual(threeBettors('SB', 'oop'), []);
});

test('threeBettorGroupTitle: single villain → "vs BB", group → "vs MP-BTN"', () => {
  assert.equal(threeBettorGroupTitle(parseScenarioKey('vs3b.utg.vs.ip')),  'vs MP-BTN');
  assert.equal(threeBettorGroupTitle(parseScenarioKey('vs3b.utg.vs.oop')), 'vs SB-BB');
  assert.equal(threeBettorGroupTitle(parseScenarioKey('vs3b.co.vs.ip')),   'vs BTN');
  assert.equal(threeBettorGroupTitle(parseScenarioKey('vs3b.co.vs.oop')),  'vs SB-BB');
  assert.equal(threeBettorGroupTitle(parseScenarioKey('vs3b.btn.vs.oop')), 'vs SB-BB');
  assert.equal(threeBettorGroupTitle(parseScenarioKey('vs3b.sb.vs.ip')),   'vs BB');
});

test('scenario titles', () => {
  assert.equal(scenarioTitle(parseScenarioKey('rfi.utg')), 'UTG RFI');
  assert.equal(scenarioTitle(parseScenarioKey('def.bb.vs.btn')), 'BB vs BTN');
  assert.equal(scenarioTitle(parseScenarioKey('vs3b.utg.vs.ip')), 'UTG vs MP-BTN');
  assert.equal(scenarioTitle(parseScenarioKey('vs4b.btn.vs.co')), 'BTN vs CO 4-Bet');
});

// ---------------------- Chart building ----------------------

test('buildChart rejects unknown chartType and bad scenario', () => {
  assert.throws(() => buildChart({ scenario: 'rfi.utg', chartType: 'nope', range: '' }),
    ChartDecodeError);
  assert.throws(() => buildChart({ scenario: 'xxx', chartType: 'rfi', range: '' }),
    ChartDecodeError);
});

test('buildChart detects overlap between fields and names the hand', () => {
  const dto = {
    scenario: 'def.bb.vs.utg', chartType: 'defense',
    threeBet: 'AA, KK', mixed3betCall: 'AA',
  };
  assert.throws(() => buildChart(dto), (err) => {
    assert.ok(err instanceof ChartDecodeError);
    assert.match(err.message, /AA/);
    assert.match(err.message, /threeBet/);
    assert.match(err.message, /mixed3betCall/);
    return true;
  });
});

test('buildChart defaults missing fields to no entries (pure fold)', () => {
  const chart = buildChart({ scenario: 'def.bb.vs.utg', chartType: 'defense',
                             threeBet: 'AA' });
  assert.deepEqual(chartAction(chart, '72o'), { kind: 'pure', action: 'fold' });
  assert.deepEqual(chartAction(chart, 'AA'),  { kind: 'pure', action: '3bet' });
});

// ---------------------- Loading all 23 charts ----------------------

test('CHART_FILES hardcoded path list has 23 unique entries', () => {
  assert.equal(CHART_FILES.length, 23);
  assert.equal(new Set(CHART_FILES).size, 23);
});

test('every one of the 23 charts loads from disk and parses', async () => {
  const charts = await loadAllChartsFromDisk();
  assert.equal(charts.length, 23);
  for (const c of charts) {
    assert.ok(c.scenario, 'has scenario');
    assert.ok(c.entries instanceof Map, 'has entries map');
  }
  // All scenario keys unique.
  const keys = charts.map(c => c.scenario.key);
  assert.equal(new Set(keys).size, 23);
});

// ---------------------- AC1.4 cross-check numbers ----------------------

test('AC1.4: bb_vs_utg has 9/11/51 (3-bet / mix / call)', async () => {
  const chart = await loadChartFromDisk('charts/defense/bb_vs_utg.json');
  let pure3 = 0, mix = 0, pureCall = 0;
  for (const ca of chart.entries.values()) {
    if (ca.kind === 'pure' && ca.action === '3bet') pure3++;
    else if (ca.kind === 'mixed') mix++;
    else if (ca.kind === 'pure' && ca.action === 'call') pureCall++;
  }
  assert.equal(pure3, 9);
  assert.equal(mix, 11);
  assert.equal(pureCall, 51);
  assert.equal(pure3 + mix + pureCall, 71);

  // Spot checks
  assert.deepEqual(chartAction(chart, 'AA'),  { kind: 'pure', action: '3bet' });
  assert.deepEqual(chartAction(chart, 'AKs'), { kind: 'pure', action: '3bet' });
  assert.deepEqual(chartAction(chart, 'JJ'),  { kind: 'mixed', aggressive: '3bet', passive: 'call' });
  assert.deepEqual(chartAction(chart, 'A7s'), { kind: 'mixed', aggressive: '3bet', passive: 'call' });
  assert.deepEqual(chartAction(chart, 'TT'),  { kind: 'pure', action: 'call' });
  assert.deepEqual(chartAction(chart, 'A8s'), { kind: 'pure', action: 'call' });
  assert.deepEqual(chartAction(chart, '72o'), { kind: 'pure', action: 'fold' });
});

test('AC1.4: bb_vs_co has 16 pure 3-bet and 10 mixed hand classes', async () => {
  const chart = await loadChartFromDisk('charts/defense/bb_vs_co.json');
  let pure3 = 0, mix = 0;
  for (const ca of chart.entries.values()) {
    if (ca.kind === 'pure' && ca.action === '3bet') pure3++;
    else if (ca.kind === 'mixed') mix++;
  }
  assert.equal(pure3, 16);
  assert.equal(mix, 10);
});

test('AC1.4: unified RFI ring assignment and strictly increasing cumulatives', async () => {
  const charts = await loadAllChartsFromDisk();
  const u = unifiedRFI(charts);
  assert.ok(u, 'unified built');

  // AA, KK are in the UTG ring (opened from UTG).
  assert.equal(u.ringFor('AA'), 'UTG');
  assert.equal(u.ringFor('KK'), 'UTG');

  // Every hand UTG opens must land in the UTG ring.
  const utgChart = charts.find(c => c.scenario.key === 'rfi.utg');
  for (const [hand, ca] of utgChart.entries) {
    if (actionContains(ca, 'open')) {
      assert.equal(u.ringFor(hand), 'UTG', `UTG-opened ${hand} should be in UTG ring`);
    }
  }

  // 72o is folded by every position.
  assert.equal(u.ringFor('72o'), null);

  // Cumulative fractions strictly increase UTG < MP < CO < BTN < 1.
  const utg = u.cumulativeFraction('UTG');
  const mp  = u.cumulativeFraction('MP');
  const co  = u.cumulativeFraction('CO');
  const btn = u.cumulativeFraction('BTN');
  assert.ok(utg < mp,  `UTG(${utg}) < MP(${mp})`);
  assert.ok(mp  < co,  `MP(${mp}) < CO(${co})`);
  assert.ok(co  < btn, `CO(${co}) < BTN(${btn})`);
  assert.ok(btn < 1,   `BTN(${btn}) < 1`);
});

// ---------------------- Combo counting & fractions ----------------------

test('comboCountContaining for RFI = sum of opened combos', async () => {
  const utg = await loadChartFromDisk('charts/rfi/utg.json');
  const openCombos = comboCountContaining(utg, 'open');
  assert.equal(openCombos, pureComboCountFor(utg, 'open'));
  assert.ok(openCombos > 0 && openCombos < TOTAL_COMBOS);
});

test('mixed combos split by two-black-cards rule', () => {
  const chart = buildChart({
    scenario: 'def.bb.vs.utg', chartType: 'defense',
    mixed3betCall: 'JJ',  // 6 combos: 1 both-black (aggressive) + 5 passive
  });
  assert.equal(comboCountContaining(chart, '3bet'), 1);
  assert.equal(comboCountContaining(chart, 'call'), 5);
});

// ---------------------- Grading: all mismatch kinds ----------------------

test('gradeOne: correct, missed, wrongExtra, wrongAction (every kind)', () => {
  const pureOpen = { kind: 'pure', action: 'open' };
  const pureFold = { kind: 'pure', action: 'fold' };
  const pure3    = { kind: 'pure', action: '3bet' };
  const pureCall = { kind: 'pure', action: 'call' };
  const mix3Call = { kind: 'mixed', aggressive: '3bet', passive: 'call' };
  const mix3Fold = { kind: 'mixed', aggressive: '3bet', passive: 'fold' };

  // Exact match (pure/pure)
  assert.equal(gradeOne(pureOpen, pureOpen), 'correct');
  // Exact match (mixed/mixed)
  assert.equal(gradeOne(mix3Call, mix3Call), 'correct');
  // Correct fold
  assert.equal(gradeOne(pureFold, pureFold), 'correct');
  // Missed: user fold, chart non-fold
  assert.equal(gradeOne(pureFold, pure3), 'missed');
  assert.equal(gradeOne(pureFold, mix3Call), 'missed');
  // Extra: user non-fold, chart fold
  assert.equal(gradeOne(pure3, pureFold), 'wrongExtra');
  assert.equal(gradeOne(mix3Call, pureFold), 'wrongExtra');
  // Wrong action: both non-fold but differ
  assert.equal(gradeOne(pure3, pureCall),   'wrongAction'); // pure vs pure
  assert.equal(gradeOne(pure3, mix3Call),   'wrongAction'); // pure vs mixed
  assert.equal(gradeOne(mix3Call, pure3),   'wrongAction'); // mixed vs pure
  assert.equal(gradeOne(mix3Call, mix3Fold),'wrongAction'); // mixed vs mixed, different legs
});

test('gradeChart: full-chart grading counts match', async () => {
  const chart = await loadChartFromDisk('charts/defense/bb_vs_utg.json');
  // Submit an empty answer: everything the chart wants should be "missed",
  // folds stay correct.
  const result = gradeChart(new Map(), chart);
  const chartNonFoldClasses = handClassCountContaining(chart, '3bet')
    + handClassCountContaining(chart, 'call')
    - 0; // (no double-counting: mixed includes 3bet AND call so subtract overlap)
  // Easier: count hand classes with any non-fold chart action.
  let nonFold = 0;
  for (const ca of chart.entries.values()) {
    if (!(ca.kind === 'pure' && ca.action === 'fold')) nonFold++;
  }
  assert.equal(result.missed, nonFold);
  assert.equal(result.wrongAction, 0);
  assert.equal(result.wrongExtra, 0);
  assert.equal(result.correct + result.missed, 169);
});

// ---------------------- Recall palette ----------------------

test('recallPaletteFor BB vs UTG offers 3-Bet, 3-Bet/Call, Call', async () => {
  const chart = await loadChartFromDisk('charts/defense/bb_vs_utg.json');
  const opts = recallPaletteFor(chart);
  const labels = opts.map(o => o.label);
  assert.deepEqual(labels, ['3-Bet', '3-Bet/Call', 'Call']);
});

test('recallPaletteFor UTG RFI offers only Open', async () => {
  const chart = await loadChartFromDisk('charts/rfi/utg.json');
  const opts = recallPaletteFor(chart);
  assert.deepEqual(opts.map(o => o.label), ['Open']);
});

// ---------------------- Category filtering ----------------------

test('categories expose all 10 top-level groups in order', () => {
  assert.deepEqual(CATEGORIES.map(c => c.id), [
    'rfi','btnDefense','sbDefense','bbDefense',
    'utgVs3bet','coVs3bet','btnVs3bet','sbVs3bet',
    'btnVs4bet','sbVs4bet',
  ]);
});

test('chartsForCategory("rfi") returns 5 RFI charts in UTG..BB action order', async () => {
  const all = await loadAllChartsFromDisk();
  const list = chartsForCategory('rfi', all);
  assert.equal(list.length, 5);
  assert.deepEqual(list.map(c => c.scenario.hero), ['UTG','MP','CO','BTN','SB']);
});

test('chartsForCategory sorts defense by villain action order', async () => {
  const all = await loadAllChartsFromDisk();
  const list = chartsForCategory('bbDefense', all);
  assert.deepEqual(list.map(c => c.scenario.villain), ['UTG','CO','BTN']);
});

test('chartsForCategory vs3bet puts ip before oop', async () => {
  const all = await loadAllChartsFromDisk();
  const list = chartsForCategory('utgVs3bet', all);
  assert.deepEqual(list.map(c => c.scenario.group), ['ip','oop']);
});
