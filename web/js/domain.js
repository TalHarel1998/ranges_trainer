// Pure domain logic for PreflopT web. No DOM access; importable from Node.
// Mirrors the Swift sources under PreflopT/PreflopT/Domain/.

export const RANKS = Object.freeze(['A','K','Q','J','T','9','8','7','6','5','4','3','2']);
export const RANK_INDEX = Object.freeze(Object.fromEntries(RANKS.map((r, i) => [r, i])));

// Preflop action order; UTG → BB.
export const POSITIONS = Object.freeze(['UTG','MP','CO','BTN','SB','BB']);
export const POSITION_ORDER = Object.freeze(Object.fromEntries(POSITIONS.map((p, i) => [p, i])));
// Post-flop acting order (first to last): SB(0), BB(1), UTG(2), MP(3), CO(4), BTN(5).
export const POSTFLOP_ORDER = Object.freeze({ SB: 0, BB: 1, UTG: 2, MP: 3, CO: 4, BTN: 5 });

export const ACTIONS = Object.freeze(['fold','call','open','3bet','4bet','5bet']);
export const GRID_SIZE = 13;
export const TOTAL_COMBOS = 1326;

// ---- Hand-class helpers ---------------------------------------------------

// Parse a canonical hand symbol like "AA", "AKs", "AKo" into
// { high, low, isPair, isSuited, symbol } (uppercase ranks, lowercase suit).
// Returns null for anything malformed.
export function parseHand(symbol) {
  if (symbol == null) return null;
  const raw = String(symbol);
  if (raw.length === 2) {
    const a = raw[0].toUpperCase(), b = raw[1].toUpperCase();
    if (!(a in RANK_INDEX) || !(b in RANK_INDEX) || a !== b) return null;
    return { high: a, low: a, isPair: true, isSuited: false, symbol: a + a };
  }
  if (raw.length === 3) {
    const a = raw[0].toUpperCase(), b = raw[1].toUpperCase(), suit = raw[2].toLowerCase();
    if (!(a in RANK_INDEX) || !(b in RANK_INDEX) || a === b) return null;
    if (suit !== 's' && suit !== 'o') return null;
    const ia = RANK_INDEX[a], ib = RANK_INDEX[b];
    const high = ia < ib ? a : b;
    const low  = ia < ib ? b : a;
    return { high, low, isPair: false, isSuited: suit === 's', symbol: high + low + suit };
  }
  return null;
}

// Combos per hand class: pair=6, suited=4, offsuit=12. Sum = 1326.
export function handCombos(symbol) {
  if (symbol.length === 2) return 6;
  return symbol[2] === 's' ? 4 : 12;
}

// Combos within this class where both hole cards are black (♠/♣).
// pair=1, suited=2, offsuit=2. Used by the two-black-cards rule for mixed cells.
export function bothBlackCombos(symbol) {
  if (symbol.length === 2) return 1;
  return 2;
}

// Grid cell at (row, col). row 0 = A row, col 0 = A col.
// Diagonal = pair, row<col = suited, row>col = offsuit.
export function handAt(row, col) {
  if (row === col) return RANKS[row] + RANKS[row];
  if (row < col) return RANKS[row] + RANKS[col] + 's';
  return RANKS[col] + RANKS[row] + 'o';
}

// Row/col of the given hand class on the standard 13×13 grid.
export function coordOf(symbol) {
  const h = parseHand(symbol);
  if (!h) return null;
  const hi = RANK_INDEX[h.high], lo = RANK_INDEX[h.low];
  if (h.isPair) return { row: hi, col: hi };
  if (h.isSuited) return { row: hi, col: lo };
  return { row: lo, col: hi };
}

// All 169 hand classes in grid order (row-major, A-to-2).
export function allHands() {
  const out = [];
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) out.push(handAt(r, c));
  }
  return out;
}

// ---- Range string parser --------------------------------------------------
//
// Grammar: comma-separated tokens; whitespace tolerated. Each token is a hand
// (AA / AKs / AKo) optionally followed by '+' which expands upward.
//   22+   → 22..AA (all pairs ≥ anchor)
//   A2s+  → A2s, A3s, ..., AKs
//   K9o+  → K9o, KTo, KJo, KQo
// Invalid tokens throw. Empty input returns an empty set.

export class RangeParseError extends Error {
  constructor(msg) { super(msg); this.name = 'RangeParseError'; }
}

export function parseRange(input) {
  const out = new Set();
  if (input == null) return out;
  const str = String(input);
  if (str.trim().length === 0) return out;
  const tokens = str.split(',').map(s => s.trim()).filter(t => t.length > 0);
  for (const tok of tokens) expandToken(tok, out);
  return out;
}

function expandToken(tok, out) {
  if (!tok) throw new RangeParseError('Empty token');
  const hasPlus = tok.endsWith('+');
  const body = hasPlus ? tok.slice(0, -1) : tok;
  const hand = parseHand(body);
  if (!hand) throw new RangeParseError(`Invalid range token: '${tok}'`);
  if (!hasPlus) { out.add(hand.symbol); return; }

  if (hand.isPair) {
    const anchor = RANK_INDEX[hand.high];
    // Pairs with rank >= anchor. In our index, that's indices 0..anchor.
    for (let i = 0; i <= anchor; i++) out.add(RANKS[i] + RANKS[i]);
    return;
  }
  // Non-pair: keep high rank, walk low rank upward through (high - 1).
  const highIdx = RANK_INDEX[hand.high];
  const fromIdx = RANK_INDEX[hand.low];
  if (fromIdx <= highIdx) {
    throw new RangeParseError(`Invalid plus-expansion anchor: '${tok}'`);
  }
  const suit = hand.isSuited ? 's' : 'o';
  for (let i = fromIdx; i > highIdx; i--) {
    out.add(hand.high + RANKS[i] + suit);
  }
}

// ---- Scenario -------------------------------------------------------------

export function parseScenarioKey(key) {
  if (typeof key !== 'string') return null;
  const parts = key.toLowerCase().split('.');
  if (parts.length < 2) return null;
  switch (parts[0]) {
    case 'rfi': {
      if (parts.length !== 2) return null;
      const hero = parts[1].toUpperCase();
      if (!POSITIONS.includes(hero)) return null;
      return { kind: 'rfi', hero, key };
    }
    case 'def': {
      if (parts.length !== 4 || parts[2] !== 'vs') return null;
      const hero = parts[1].toUpperCase();
      const villain = parts[3].toUpperCase();
      if (!POSITIONS.includes(hero) || !POSITIONS.includes(villain)) return null;
      return { kind: 'defense', hero, villain, key };
    }
    case 'vs3b': {
      if (parts.length !== 4 || parts[2] !== 'vs') return null;
      const hero = parts[1].toUpperCase();
      const group = parts[3];
      if (!POSITIONS.includes(hero) || (group !== 'ip' && group !== 'oop')) return null;
      return { kind: 'vs3bet', hero, group, key };
    }
    case 'vs4b': {
      if (parts.length !== 4 || parts[2] !== 'vs') return null;
      const hero = parts[1].toUpperCase();
      const villain = parts[3].toUpperCase();
      if (!POSITIONS.includes(hero) || !POSITIONS.includes(villain)) return null;
      return { kind: 'vs4bet', hero, villain, key };
    }
    default: return null;
  }
}

// Villain positions that could 3-bet hero. "ip" = post-flop in position
// relative to hero (post-flop order greater); "oop" = post-flop out of position.
export function threeBettors(hero, group) {
  const heroPre = POSITION_ORDER[hero];
  const heroPf = POSTFLOP_ORDER[hero];
  return POSITIONS
    .filter(p => POSITION_ORDER[p] > heroPre)
    .filter(p => group === 'ip' ? POSTFLOP_ORDER[p] > heroPf : POSTFLOP_ORDER[p] < heroPf)
    .sort((a, b) => POSITION_ORDER[a] - POSITION_ORDER[b]);
}

export function threeBettorGroupTitle(scenario) {
  if (!scenario || scenario.kind !== 'vs3bet') return null;
  const list = threeBettors(scenario.hero, scenario.group);
  if (list.length === 0) return null;
  if (list.length === 1) return `vs ${list[0]}`;
  return `vs ${list[0]}-${list[list.length - 1]}`;
}

// Human-readable chart title: "UTG RFI", "BB vs BTN", "UTG vs MP-BTN",
// "BTN vs CO 4-Bet".
export function scenarioTitle(scenario) {
  switch (scenario.kind) {
    case 'rfi':     return `${scenario.hero} RFI`;
    case 'defense': return `${scenario.hero} vs ${scenario.villain}`;
    case 'vs3bet': {
      const suf = threeBettorGroupTitle(scenario) ?? 'vs 3-Bet';
      return `${scenario.hero} ${suf}`;
    }
    case 'vs4bet':  return `${scenario.hero} vs ${scenario.villain} 4-Bet`;
    default: return '?';
  }
}

// Row label inside a category list: "vs UTG", "vs MP-BTN", "vs CO".
export function scenarioRowLabel(scenario) {
  switch (scenario.kind) {
    case 'rfi':     return scenario.hero;
    case 'defense': return `vs ${scenario.villain}`;
    case 'vs3bet':  return threeBettorGroupTitle(scenario) ?? 'vs 3-Bet';
    case 'vs4bet':  return `vs ${scenario.villain}`;
    default: return '?';
  }
}

// ---- Chart building -------------------------------------------------------

export class ChartDecodeError extends Error {
  constructor(msg) { super(msg); this.name = 'ChartDecodeError'; }
}

const VALID_CHART_TYPES = new Set(['rfi','defense','vs3bet','vs4bet']);

// Build a domain chart from the raw DTO parsed from JSON. Throws
// ChartDecodeError with a descriptive message on any error.
export function buildChart(dto) {
  if (!dto || typeof dto !== 'object') {
    throw new ChartDecodeError('Chart JSON must be an object');
  }
  const scenario = parseScenarioKey(dto.scenario || '');
  if (!scenario) throw new ChartDecodeError(`Invalid scenario key: '${dto.scenario}'`);
  const type = dto.chartType;
  if (!VALID_CHART_TYPES.has(type)) {
    throw new ChartDecodeError(`Unknown chartType: '${type}'`);
  }
  if (type !== scenario.kind) {
    // Not strictly required by the spec, but a nice sanity check.
    throw new ChartDecodeError(`chartType '${type}' does not match scenario '${scenario.key}'`);
  }

  const expand = (input, field) => {
    try { return parseRange(input ?? ''); }
    catch (err) {
      throw new ChartDecodeError(`Failed to parse range in field '${field}': ${err.message}`);
    }
  };
  const checkOverlap = (groups) => {
    const seen = new Map();
    for (const [name, set] of groups) {
      for (const h of set) {
        const arr = seen.get(h);
        if (arr) arr.push(name); else seen.set(h, [name]);
      }
    }
    for (const [hand, names] of seen) {
      if (names.length > 1) return { hand, names };
    }
    return null;
  };

  const entries = new Map();

  if (type === 'rfi') {
    if (dto.range == null) {
      throw new ChartDecodeError(`Chart type 'rfi' requires field 'range'`);
    }
    const hands = expand(dto.range, 'range');
    for (const h of hands) entries.set(h, { kind: 'pure', action: 'open' });
  } else if (type === 'defense') {
    const t = expand(dto.threeBet,      'threeBet');
    const mc = expand(dto.mixed3betCall, 'mixed3betCall');
    const mf = expand(dto.mixed3betFold, 'mixed3betFold');
    const c = expand(dto.call,           'call');
    const dup = checkOverlap([
      ['threeBet', t], ['mixed3betCall', mc], ['mixed3betFold', mf], ['call', c],
    ]);
    if (dup) {
      throw new ChartDecodeError(
        `Hand '${dup.hand}' appears in multiple defense fields: ${dup.names.join(', ')}`
      );
    }
    for (const h of t)  entries.set(h, { kind: 'pure', action: '3bet' });
    for (const h of mc) entries.set(h, { kind: 'mixed', aggressive: '3bet', passive: 'call' });
    for (const h of mf) entries.set(h, { kind: 'mixed', aggressive: '3bet', passive: 'fold' });
    for (const h of c)  entries.set(h, { kind: 'pure', action: 'call' });
  } else if (type === 'vs3bet') {
    const f  = expand(dto.fourBet,       'fourBet');
    const mc = expand(dto.mixed4betCall, 'mixed4betCall');
    const c  = expand(dto.call,          'call');
    const dup = checkOverlap([['fourBet', f], ['mixed4betCall', mc], ['call', c]]);
    if (dup) {
      throw new ChartDecodeError(
        `Hand '${dup.hand}' appears in multiple vs3bet fields: ${dup.names.join(', ')}`
      );
    }
    for (const h of f)  entries.set(h, { kind: 'pure', action: '4bet' });
    for (const h of mc) entries.set(h, { kind: 'mixed', aggressive: '4bet', passive: 'call' });
    for (const h of c)  entries.set(h, { kind: 'pure', action: 'call' });
  } else { // vs4bet
    const f  = expand(dto.fiveBet,       'fiveBet');
    const mc = expand(dto.mixed5betCall, 'mixed5betCall');
    const c  = expand(dto.call,          'call');
    const dup = checkOverlap([['fiveBet', f], ['mixed5betCall', mc], ['call', c]]);
    if (dup) {
      throw new ChartDecodeError(
        `Hand '${dup.hand}' appears in multiple vs4bet fields: ${dup.names.join(', ')}`
      );
    }
    for (const h of f)  entries.set(h, { kind: 'pure', action: '5bet' });
    for (const h of mc) entries.set(h, { kind: 'mixed', aggressive: '5bet', passive: 'call' });
    for (const h of c)  entries.set(h, { kind: 'pure', action: 'call' });
  }

  return {
    scenario,
    openSize: dto.openSize ?? null,
    note: dto.note ?? null,
    entries,
  };
}

// Chart action for a hand (defaulting to pure fold).
export function chartAction(chart, hand) {
  return chart.entries.get(hand) ?? { kind: 'pure', action: 'fold' };
}

export function actionsEqual(a, b) {
  if (!a || !b || a.kind !== b.kind) return false;
  if (a.kind === 'pure') return a.action === b.action;
  return a.aggressive === b.aggressive && a.passive === b.passive;
}

// Does a ChartAction (or RecallAnswer) include the given pure action?
export function actionContains(ca, action) {
  if (!ca) return false;
  if (ca.kind === 'pure') return ca.action === action;
  return ca.aggressive === action || ca.passive === action;
}

// # of hand classes whose chart entry contains the given action.
export function handClassCountContaining(chart, action) {
  let n = 0;
  for (const ca of chart.entries.values()) if (actionContains(ca, action)) n++;
  return n;
}

// # of individual 2-card combos (0..1326) that resolve to the given action.
export function comboCountContaining(chart, action) {
  let total = 0;
  for (const [hand, ca] of chart.entries) {
    if (ca.kind === 'pure') {
      if (ca.action === action) total += handCombos(hand);
    } else {
      if (ca.aggressive === action) {
        total += bothBlackCombos(hand);
      } else if (ca.passive === action) {
        total += handCombos(hand) - bothBlackCombos(hand);
      }
    }
  }
  return total;
}

export function fractionContaining(chart, action) {
  return comboCountContaining(chart, action) / TOTAL_COMBOS;
}

// Combo count in a specific ChartAction bucket (for row/legend accounting).
// Mixed cells count their full 1326-combo share in the "mix" bucket.
export function mixedComboCount(chart) {
  let total = 0;
  for (const [hand, ca] of chart.entries) {
    if (ca.kind === 'mixed') total += handCombos(hand);
  }
  return total;
}

export function pureComboCountFor(chart, action) {
  let total = 0;
  for (const [hand, ca] of chart.entries) {
    if (ca.kind === 'pure' && ca.action === action) total += handCombos(hand);
  }
  return total;
}

// ---- Chart Recall grading --------------------------------------------------
//
// Per-cell grade kinds:
//   'correct'    — exact match (both pure same, both mixed same)
//   'missed'     — user folded (or left blank) but chart wants non-fold
//   'wrongExtra' — user painted non-fold on a chart-fold cell
//   'wrongAction'— both non-fold but structure differs (pure vs mixed, or
//                  different pure action, or different mixed legs)

export function gradeOne(answer, expected) {
  if (actionsEqual(answer, expected)) return 'correct';
  if (answer && answer.kind === 'pure' && answer.action === 'fold') return 'missed';
  if (expected && expected.kind === 'pure' && expected.action === 'fold') return 'wrongExtra';
  return 'wrongAction';
}

// Grade a painted answer map against a chart. `painted` is a Map (or any
// object with a `get(hand)` method) returning undefined for untouched cells.
export function gradeChart(painted, chart) {
  const grades = new Map();
  let correct = 0, missed = 0, wrongAction = 0, wrongExtra = 0;
  const get = painted instanceof Map
    ? (h) => painted.get(h)
    : (h) => painted[h];
  for (const hand of allHands()) {
    const ans = get(hand) ?? { kind: 'pure', action: 'fold' };
    const exp = chartAction(chart, hand);
    const g = gradeOne(ans, exp);
    grades.set(hand, g);
    if (g === 'correct') correct++;
    else if (g === 'missed') missed++;
    else if (g === 'wrongAction') wrongAction++;
    else if (g === 'wrongExtra') wrongExtra++;
  }
  return { grades, correct, missed, wrongAction, wrongExtra };
}

// ---- Unified RFI chart -----------------------------------------------------

// Build the unified ring assignment from a mixed list of charts.
// Returns null if any of UTG/MP/CO/BTN RFI charts are missing.
export function unifiedRFI(allCharts) {
  const byPos = {};
  for (const c of allCharts) {
    if (c.scenario.kind === 'rfi') byPos[c.scenario.hero] = c;
  }
  if (!byPos.UTG || !byPos.MP || !byPos.CO || !byPos.BTN) return null;

  const ringByHand = new Map();
  for (const hand of allHands()) {
    for (const pos of ['UTG','MP','CO','BTN']) {
      const chart = byPos[pos];
      if (actionContains(chartAction(chart, hand), 'open')) {
        ringByHand.set(hand, pos === 'BTN' ? 'BTN/SB' : pos);
        break;
      }
    }
  }

  return {
    ringByHand,
    chartsByPosition: byPos,
    ringFor(hand) { return ringByHand.get(hand) ?? null; },
    cumulativeCombos(position) {
      const chart = byPos[position];
      return chart ? comboCountContaining(chart, 'open') : 0;
    },
    cumulativeFraction(position) {
      return this.cumulativeCombos(position) / TOTAL_COMBOS;
    },
  };
}

// ---- Recall palette derivation --------------------------------------------
//
// Picks the paint options to offer the user based on the actions the chart
// actually uses. Ordered Open, All-In, 4-Bet, 3-Bet, All-In/Call, 4-Bet/Call,
// 3-Bet/Call, 3-Bet/Fold, Call (first = selected by default).

export function recallPaletteFor(chart) {
  const flags = {
    pureOpen: false, pure5bet: false, pure4bet: false, pure3bet: false,
    pureCall: false,
    mixed5betCall: false, mixed4betCall: false,
    mixed3betCall: false, mixed3betFold: false,
  };
  for (const ca of chart.entries.values()) {
    if (ca.kind === 'pure') {
      if (ca.action === 'open') flags.pureOpen = true;
      else if (ca.action === '3bet') flags.pure3bet = true;
      else if (ca.action === '4bet') flags.pure4bet = true;
      else if (ca.action === '5bet') flags.pure5bet = true;
      else if (ca.action === 'call') flags.pureCall = true;
    } else {
      if (ca.aggressive === '3bet' && ca.passive === 'call') flags.mixed3betCall = true;
      else if (ca.aggressive === '3bet' && ca.passive === 'fold') flags.mixed3betFold = true;
      else if (ca.aggressive === '4bet' && ca.passive === 'call') flags.mixed4betCall = true;
      else if (ca.aggressive === '5bet' && ca.passive === 'call') flags.mixed5betCall = true;
    }
  }
  const opts = [];
  if (flags.pureOpen)      opts.push({ label: 'Open',    answer: { kind: 'pure', action: 'open' } });
  if (flags.pure5bet)      opts.push({ label: 'All-In',  answer: { kind: 'pure', action: '5bet' } });
  if (flags.pure4bet)      opts.push({ label: '4-Bet',   answer: { kind: 'pure', action: '4bet' } });
  if (flags.pure3bet)      opts.push({ label: '3-Bet',   answer: { kind: 'pure', action: '3bet' } });
  if (flags.mixed5betCall) opts.push({ label: 'All-In/Call', answer: { kind: 'mixed', aggressive: '5bet', passive: 'call' } });
  if (flags.mixed4betCall) opts.push({ label: '4-Bet/Call',  answer: { kind: 'mixed', aggressive: '4bet', passive: 'call' } });
  if (flags.mixed3betCall) opts.push({ label: '3-Bet/Call',  answer: { kind: 'mixed', aggressive: '3bet', passive: 'call' } });
  if (flags.mixed3betFold) opts.push({ label: '3-Bet/Fold',  answer: { kind: 'mixed', aggressive: '3bet', passive: 'fold' } });
  if (flags.pureCall)      opts.push({ label: 'Call',    answer: { kind: 'pure', action: 'call' } });
  if (opts.length === 0)   opts.push({ label: 'Open',    answer: { kind: 'pure', action: 'open' } });
  return opts;
}

// ---- Categories -----------------------------------------------------------

export const CATEGORIES = Object.freeze([
  { id: 'rfi',        title: 'RFI' },
  { id: 'btnDefense', title: 'BTN defense', hero: 'BTN', kind: 'defense' },
  { id: 'sbDefense',  title: 'SB defense',  hero: 'SB',  kind: 'defense' },
  { id: 'bbDefense',  title: 'BB defense',  hero: 'BB',  kind: 'defense' },
  { id: 'utgVs3bet',  title: 'UTG vs 3-Bet', hero: 'UTG', kind: 'vs3bet' },
  { id: 'coVs3bet',   title: 'CO vs 3-Bet',  hero: 'CO',  kind: 'vs3bet' },
  { id: 'btnVs3bet',  title: 'BTN vs 3-Bet', hero: 'BTN', kind: 'vs3bet' },
  { id: 'sbVs3bet',   title: 'SB vs 3-Bet',  hero: 'SB',  kind: 'vs3bet' },
  { id: 'btnVs4bet',  title: 'BTN vs 4-Bet', hero: 'BTN', kind: 'vs4bet' },
  { id: 'sbVs4bet',   title: 'SB vs 4-Bet',  hero: 'SB',  kind: 'vs4bet' },
]);

export function chartsForCategory(categoryId, allCharts) {
  const cat = CATEGORIES.find(c => c.id === categoryId);
  if (!cat) return [];
  if (cat.id === 'rfi') {
    return allCharts
      .filter(c => c.scenario.kind === 'rfi')
      .sort((a, b) => POSITION_ORDER[a.scenario.hero] - POSITION_ORDER[b.scenario.hero]);
  }
  const list = allCharts.filter(c => c.scenario.kind === cat.kind && c.scenario.hero === cat.hero);
  if (cat.kind === 'defense') {
    list.sort((a, b) => POSITION_ORDER[a.scenario.villain] - POSITION_ORDER[b.scenario.villain]);
  } else if (cat.kind === 'vs3bet') {
    // IP before OOP.
    list.sort((a, b) => (a.scenario.group === 'ip' ? 0 : 1) - (b.scenario.group === 'ip' ? 0 : 1));
  } else if (cat.kind === 'vs4bet') {
    list.sort((a, b) => POSITION_ORDER[a.scenario.villain] - POSITION_ORDER[b.scenario.villain]);
  }
  return list;
}
