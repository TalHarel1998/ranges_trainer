// UI layer: hash routing, DOM building, drag-to-paint, GitHub connection
// and chart/palette editors. Pure logic lives in domain.js and serialize.js;
// palette parsing in colors.js. This module touches the DOM.

import {
  CATEGORIES, GRID_SIZE, TOTAL_COMBOS,
  allHands, handAt, parseScenarioKey, scenarioTitle, scenarioRowLabel,
  chartsForCategory, chartAction, actionsEqual,
  handCombos, fractionContaining, gradeChart,
  pureComboCountFor, mixedComboCount, recallPaletteFor, unifiedRFI,
  buildChart,
} from './domain.js';
import {
  CHART_FILES, fetchChartText, fetchAllChartTexts, parseChartText,
  buildAllCharts, ChartLoadError,
} from './charts.js';
import {
  DEFAULT_PALETTE, DEFAULT_RFI_PALETTE,
  parsePaletteFile, serializePaletteFile, palettesEqual,
  colorForAction, colorForChartAction, colorForRing, cellFill,
  resolveAutoFoldColor, foregroundOn,
} from './colors.js';
import {
  PALETTE_APP_PATH, PALETTE_REPO_PATH,
  appPathToRepoPath,
} from './config.js';
import {
  getToken, setToken, clearToken,
  loadPendingWrites, savePendingWrites, recordPendingWrite,
  clearOldPaletteKeys, reconcilePendingWrites,
} from './store.js';
import {
  testConnection, testWriteAccess, getFile, putFile, GitHubError,
} from './github.js';
import { chartToFileJSON } from './serialize.js';

// ------------------- DOM helpers -------------------

function h(tag, attrs = {}, children = []) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k === 'style') el.setAttribute('style', v);
    else if (k.startsWith('on') && typeof v === 'function') {
      el.addEventListener(k.slice(2).toLowerCase(), v);
    } else if (k === 'disabled') {
      if (v) el.setAttribute('disabled', '');
    } else if (k === 'checked') {
      if (v) el.checked = true;
    } else if (k === 'value' && (tag === 'input' || tag === 'textarea')) {
      el.value = v;
    } else {
      el.setAttribute(k, v);
    }
  }
  const arr = Array.isArray(children) ? children : [children];
  for (const c of arr) {
    if (c == null || c === false) continue;
    if (typeof c === 'string' || typeof c === 'number') {
      el.appendChild(document.createTextNode(String(c)));
    } else {
      el.appendChild(c);
    }
  }
  return el;
}

function clear(root) { while (root.firstChild) root.removeChild(root.firstChild); }

// ------------------- State -------------------

const state = {
  allCharts: [],
  chartByKey: new Map(),
  pathByScenarioKey: new Map(),
  unified: null,
  // Currently-applied palette (edited colors reflect here immediately).
  palette: { ...DEFAULT_PALETTE },
  rfiPalette: { ...DEFAULT_RFI_PALETTE },
  // Palette as last loaded or saved from the repo (used to revert on leave).
  savedPalette: { ...DEFAULT_PALETTE },
  savedRfiPalette: { ...DEFAULT_RFI_PALETTE },
  // Original on-disk texts, used by the editor as a source of truth to diff
  // against for byte-identical file output.
  chartTextByPath: new Map(),
  loadError: null,
  // Current view's redraw hook — set by renderers that need to redraw after
  // a palette change.
  onPaletteChange: null,
};

// ------------------- Unsaved-changes guard -------------------

let unsavedGuard = null;      // { hash, hasChanges() }
let suppressNextHashChange = false;

// ------------------- Commit re-entrancy flags -------------------
// Second invocations while a commit is in flight are ignored instead of
// relying on the button's `disabled` attribute, which can be bypassed by
// focus-triggered keyboard activation or by stale references after a
// re-render.
let editorCommitInFlight = false;
let paletteSaveInFlight = false;

function setUnsavedGuard(hash, hasChanges) {
  unsavedGuard = { hash, hasChanges };
}

function clearUnsavedGuard() { unsavedGuard = null; }

// ------------------- Toasts -------------------

function ensureToastRoot() {
  let el = document.getElementById('toasts');
  if (!el) {
    el = h('div', { id: 'toasts', class: 'toasts', role: 'status', 'aria-live': 'polite' });
    document.body.appendChild(el);
  }
  return el;
}

function toast(message, { kind = 'info', ttl = 4000 } = {}) {
  const root = ensureToastRoot();
  // AC F15/UX: cap the visible stack to 2, drop oldest.
  while (root.children.length >= 2) {
    root.removeChild(root.firstChild);
  }
  const el = h('div', { class: `toast toast-${kind}` }, message);
  root.appendChild(el);
  setTimeout(() => { try { el.remove(); } catch {} }, ttl);
}

// ------------------- Inline error box (text nodes only) -------------------

function tokenRejectedChildren(lead = 'Token rejected — check it in ') {
  // Builds the children of a token error message using text nodes and a
  // single anchor. No innerHTML, no HTML parsing of remote text (AC15.2).
  return [
    lead,
    h('a', { href: '#/github' }, 'GitHub settings'),
    '.',
  ];
}

// 401 = GitHub doesn't accept the token at all (expired, revoked, mistyped).
// 403/404 on a write = the token is valid but lacks "Contents: Read and write"
// on this repo (a fine-grained token's own permissions, not the account's).
function tokenErrorLead(kind) {
  if (kind === 'forbidden' || kind === 'noWrite') {
    return 'Token can’t write to ranges_trainer. On GitHub, edit the token: Repository permissions → Contents: Read and write. Then check it in ';
  }
  return 'Token rejected (expired, revoked or mistyped) — check it in ';
}

function setInlineError(container, children) {
  if (!container) return;
  clear(container);
  for (const c of (Array.isArray(children) ? children : [children])) {
    if (c == null || c === false) continue;
    if (typeof c === 'string' || typeof c === 'number') {
      container.appendChild(document.createTextNode(String(c)));
    } else {
      container.appendChild(c);
    }
  }
  container.hidden = false;
}

function clearInlineError(container) {
  if (!container) return;
  clear(container);
  container.hidden = true;
}

// ------------------- Grid helpers -------------------

function buildGrid({ interactive = false, onPaint = null, isEraseStart = null } = {}) {
  const grid = h('div', {
    class: 'grid' + (interactive ? ' interactive' : ''),
    role: 'grid',
    'aria-label': '13 by 13 preflop hand grid',
  });
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      const hand = handAt(r, c);
      const cell = h('div', {
        class: 'cell',
        role: 'gridcell',
        'data-hand': hand,
        'data-row': r,
        'data-col': c,
      }, [
        h('span', { class: 'cell-label' }, hand),
      ]);
      grid.appendChild(cell);
    }
  }
  if (interactive && typeof onPaint === 'function') {
    attachPainting(grid, { onPaint, isEraseStart });
  }
  return grid;
}

function paintCell(cell, fill, fg, outline) {
  // `fill` may be a solid color (e.g. "#38B359") or a CSS gradient (used
  // by F17 split cells for mixed actions). Using the `background`
  // shorthand means a later solid color correctly clears any previously
  // applied gradient.
  cell.style.background = fill;
  cell.style.color = fg;
  cell.classList.toggle('split-text', !!outline);
}

function attachPainting(grid, { onPaint, isEraseStart }) {
  function cellHandAt(x, y) {
    const el = document.elementFromPoint(x, y);
    if (!el) return null;
    const cell = el.closest('.cell');
    if (!cell || !grid.contains(cell)) return null;
    return cell.dataset.hand;
  }

  grid.addEventListener('pointerdown', (e) => {
    const cell = e.target.closest?.('.cell');
    if (!cell || !grid.contains(cell)) return;
    e.preventDefault();
    const startHand = cell.dataset.hand;
    try { e.target.releasePointerCapture?.(e.pointerId); } catch {}
    const erase = typeof isEraseStart === 'function' ? !!isEraseStart(startHand) : false;
    const activated = new Set();
    const activate = (hand) => {
      if (!hand || activated.has(hand)) return;
      activated.add(hand);
      onPaint(hand, erase);
    };
    activate(startHand);

    const onMove = (ev) => {
      ev.preventDefault();
      activate(cellHandAt(ev.clientX, ev.clientY));
    };
    const cleanup = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', cleanup);
      window.removeEventListener('pointercancel', cleanup);
    };
    window.addEventListener('pointermove', onMove, { passive: false });
    window.addEventListener('pointerup', cleanup);
    window.addEventListener('pointercancel', cleanup);
  });
}

// ------------------- Legend building -------------------

function pct(frac) { return (frac * 100).toFixed(1) + '%'; }

function legendItemEl(fill, label, frac) {
  // `fill` may be a solid color or a CSS gradient (F17 mixed swatches).
  return h('div', { class: 'legend-item' }, [
    h('span', { class: 'swatch', style: `background: ${fill}` }),
    h('span', { class: 'legend-label' }, label),
    h('span', { class: 'legend-pct' }, pct(frac)),
  ]);
}

function foldColor() { return state.palette.fold ?? resolveAutoFoldColor(); }

function buildChartLegend(chart) {
  const items = [];
  if (chart.scenario.kind === 'rfi') {
    const openFrac = fractionContaining(chart, 'open');
    items.push(legendItemEl(colorForAction(state.palette, 'open'), 'Open', openFrac));
    items.push(legendItemEl(foldColor(), 'Fold', 1 - openFrac));
  } else if (chart.scenario.kind === 'defense') {
    let pure3 = 0, mc = 0, mf = 0, pc = 0;
    for (const [hand, ca] of chart.entries) {
      if (ca.kind === 'pure' && ca.action === '3bet') pure3 += handCombos(hand);
      else if (ca.kind === 'pure' && ca.action === 'call') pc += handCombos(hand);
      else if (ca.kind === 'mixed' && ca.aggressive === '3bet' && ca.passive === 'call') mc += handCombos(hand);
      else if (ca.kind === 'mixed' && ca.aggressive === '3bet' && ca.passive === 'fold') mf += handCombos(hand);
    }
    const pFrac = pure3 / TOTAL_COMBOS, mFrac = (mc + mf) / TOTAL_COMBOS, cFrac = pc / TOTAL_COMBOS;
    const fFrac = Math.max(0, 1 - pFrac - mFrac - cFrac);
    let mixLabel = 'Mix';
    let mixCa = { kind: 'mixed', aggressive: '3bet', passive: 'call' };
    if (mc > 0 && mf === 0) mixLabel = '3-Bet/Call';
    else if (mf > 0 && mc === 0) { mixLabel = '3-Bet/Fold'; mixCa = { kind: 'mixed', aggressive: '3bet', passive: 'fold' }; }
    else if (mc > 0 && mf > 0) mixLabel = 'Mixed';
    items.push(legendItemEl(colorForAction(state.palette, '3bet'), '3-Bet', pFrac));
    if (mFrac > 0) items.push(legendItemEl(cellFill(state.palette, mixCa).background, mixLabel, mFrac));
    if (cFrac > 0) items.push(legendItemEl(colorForAction(state.palette, 'call'), 'Call', cFrac));
    items.push(legendItemEl(foldColor(), 'Fold', fFrac));
  } else if (chart.scenario.kind === 'vs3bet') {
    let p4 = 0, mc = 0, pc = 0;
    for (const [hand, ca] of chart.entries) {
      if (ca.kind === 'pure' && ca.action === '4bet') p4 += handCombos(hand);
      else if (ca.kind === 'pure' && ca.action === 'call') pc += handCombos(hand);
      else if (ca.kind === 'mixed' && ca.aggressive === '4bet' && ca.passive === 'call') mc += handCombos(hand);
    }
    const pFrac = p4 / TOTAL_COMBOS, mFrac = mc / TOTAL_COMBOS, cFrac = pc / TOTAL_COMBOS;
    const fFrac = Math.max(0, 1 - pFrac - mFrac - cFrac);
    items.push(legendItemEl(colorForAction(state.palette, '4bet'), '4-Bet', pFrac));
    if (mFrac > 0) items.push(legendItemEl(
      cellFill(state.palette, { kind: 'mixed', aggressive: '4bet', passive: 'call' }).background,
      '4-Bet/Call', mFrac));
    if (cFrac > 0) items.push(legendItemEl(colorForAction(state.palette, 'call'), 'Call', cFrac));
    items.push(legendItemEl(foldColor(), 'Fold', fFrac));
  } else if (chart.scenario.kind === 'vs4bet') {
    let p5 = 0, mc = 0, pc = 0;
    for (const [hand, ca] of chart.entries) {
      if (ca.kind === 'pure' && ca.action === '5bet') p5 += handCombos(hand);
      else if (ca.kind === 'pure' && ca.action === 'call') pc += handCombos(hand);
      else if (ca.kind === 'mixed' && ca.aggressive === '5bet' && ca.passive === 'call') mc += handCombos(hand);
    }
    const pFrac = p5 / TOTAL_COMBOS, mFrac = mc / TOTAL_COMBOS, cFrac = pc / TOTAL_COMBOS;
    const fFrac = Math.max(0, 1 - pFrac - mFrac - cFrac);
    items.push(legendItemEl(colorForAction(state.palette, '5bet'), 'All-In', pFrac));
    if (mFrac > 0) items.push(legendItemEl(
      cellFill(state.palette, { kind: 'mixed', aggressive: '5bet', passive: 'call' }).background,
      'All-In/Call', mFrac));
    if (cFrac > 0) items.push(legendItemEl(colorForAction(state.palette, 'call'), 'Call', cFrac));
    items.push(legendItemEl(foldColor(), 'Fold', fFrac));
  }
  return items;
}

// ------------------- Views -------------------

function backLink(href = '#/') {
  return h('a', { class: 'back', href }, '◀ Back');
}

function page(title, backHref, children) {
  const bar = h('div', { class: 'topbar' }, [
    backHref ? backLink(backHref) : h('span', { class: 'back-spacer' }),
    h('h1', { class: 'title' }, title),
    h('span', { class: 'back-spacer' }),
  ]);
  return h('div', { class: 'page' }, [bar, ...children]);
}

function renderError(root, message) {
  clear(root);
  root.appendChild(page('Error', '#/', [
    h('div', { class: 'error' }, message),
  ]));
}

function renderHome(root) {
  const list = h('div', { class: 'list' });
  for (const cat of CATEGORIES) {
    const charts = chartsForCategory(cat.id, state.allCharts);
    if (charts.length === 0 && cat.id !== 'rfi') continue;
    const subtitle = cat.id === 'rfi'
      ? 'Unified — all positions'
      : `${charts.length} chart${charts.length === 1 ? '' : 's'}`;
    const href = cat.id === 'rfi' ? '#/rfi' : `#/category/${cat.id}`;
    list.appendChild(h('a', { class: 'row', href }, [
      h('div', { class: 'row-main' }, [
        h('div', { class: 'row-title' }, cat.title),
        h('div', { class: 'row-sub' }, subtitle),
      ]),
      h('div', { class: 'row-chev' }, '›'),
    ]));
  }
  list.appendChild(h('a', { class: 'row', href: '#/colors' }, [
    h('div', { class: 'row-main' }, [
      h('div', { class: 'row-title' }, 'Colors'),
      h('div', { class: 'row-sub' }, 'Edit action and ring colors'),
    ]),
    h('div', { class: 'row-chev' }, '›'),
  ]));
  const hasToken = !!getToken();
  list.appendChild(h('a', { class: 'row', href: '#/github' }, [
    h('div', { class: 'row-main' }, [
      h('div', { class: 'row-title' }, 'GitHub'),
      h('div', { class: 'row-sub' }, hasToken ? 'Connected — can edit charts' : 'Add a token to edit charts'),
    ]),
    h('div', { class: 'row-chev' }, '›'),
  ]));

  clear(root);
  root.appendChild(page('GG 6-Max Cash Ranges', null, [list]));
}

// The mixed action a defense chart's "mix" pill should show, chosen the same
// way as the legend: 3-Bet/Fold when the chart only has 3-Bet/Fold mixes,
// otherwise 3-Bet/Call.
function defenseMixAction(chart) {
  let hasCall = false, hasFold = false;
  for (const ca of chart.entries.values()) {
    if (ca.kind !== 'mixed' || ca.aggressive !== '3bet') continue;
    if (ca.passive === 'call') hasCall = true;
    else if (ca.passive === 'fold') hasFold = true;
  }
  const passive = hasFold && !hasCall ? 'fold' : 'call';
  return { kind: 'mixed', aggressive: '3bet', passive };
}

function categoryRowContent(chart) {
  const scenario = chart.scenario;
  const pill = (color, text) => h('span', {
    class: 'count-pill',
    style: `background-color: ${color}; color: ${foregroundOn(color)}`,
  }, text);
  // F17.3: mix pill uses the same 50/50 split as grid cells. For
  // category rows we show the representative split for the chart type
  // (defense → 3-Bet/Call, vs3bet → 4-Bet/Call, vs4bet → All-In/Call).
  const mixPill = (ca, text) => {
    const { background, fg, outline } = cellFill(state.palette, ca);
    return h('span', {
      class: 'count-pill' + (outline ? ' split-text' : ''),
      style: `background: ${background}; color: ${fg}`,
    }, text);
  };
  if (scenario.kind === 'rfi') {
    const openCombos = pureComboCountFor(chart, 'open');
    return [
      h('div', { class: 'row-main' }, [
        h('div', { class: 'row-title' }, scenarioRowLabel(scenario)),
        h('div', { class: 'row-sub' }, 'RFI' + (chart.openSize ? ` · ${chart.openSize}` : '')),
      ]),
      h('div', { class: 'row-counts' }, [
        pill(colorForAction(state.palette, 'open'), `${openCombos} open`),
      ]),
    ];
  }
  if (scenario.kind === 'defense') {
    const t = pureComboCountFor(chart, '3bet');
    const m = mixedComboCount(chart);
    const c = pureComboCountFor(chart, 'call');
    return [
      h('div', { class: 'row-main' }, [
        h('div', { class: 'row-title' }, scenarioRowLabel(scenario)),
        h('div', { class: 'row-sub' }, 'Defense'),
      ]),
      h('div', { class: 'row-counts' }, [
        t > 0 && pill(colorForAction(state.palette, '3bet'), `${t} 3-bet`),
        m > 0 && mixPill(defenseMixAction(chart), `${m} mix`),
        c > 0 && pill(colorForAction(state.palette, 'call'), `${c} call`),
      ].filter(Boolean)),
    ];
  }
  if (scenario.kind === 'vs3bet') {
    const t = pureComboCountFor(chart, '4bet');
    const m = mixedComboCount(chart);
    const c = pureComboCountFor(chart, 'call');
    return [
      h('div', { class: 'row-main' }, [
        h('div', { class: 'row-title' }, scenarioRowLabel(scenario)),
        h('div', { class: 'row-sub' }, 'vs 3-Bet'),
      ]),
      h('div', { class: 'row-counts' }, [
        t > 0 && pill(colorForAction(state.palette, '4bet'), `${t} 4-bet`),
        m > 0 && mixPill({ kind: 'mixed', aggressive: '4bet', passive: 'call' }, `${m} mix`),
        c > 0 && pill(colorForAction(state.palette, 'call'), `${c} call`),
      ].filter(Boolean)),
    ];
  }
  if (scenario.kind === 'vs4bet') {
    const t = pureComboCountFor(chart, '5bet');
    const m = mixedComboCount(chart);
    const c = pureComboCountFor(chart, 'call');
    return [
      h('div', { class: 'row-main' }, [
        h('div', { class: 'row-title' }, scenarioRowLabel(scenario)),
        h('div', { class: 'row-sub' }, 'vs 4-Bet'),
      ]),
      h('div', { class: 'row-counts' }, [
        t > 0 && pill(colorForAction(state.palette, '5bet'), `${t} all-in`),
        m > 0 && mixPill({ kind: 'mixed', aggressive: '5bet', passive: 'call' }, `${m} mix`),
        c > 0 && pill(colorForAction(state.palette, 'call'), `${c} call`),
      ].filter(Boolean)),
    ];
  }
  return [];
}

function renderCategory(root, categoryId) {
  const cat = CATEGORIES.find(c => c.id === categoryId);
  if (!cat) { renderError(root, `Unknown category: ${categoryId}`); return; }
  if (cat.id === 'rfi') { renderUnifiedRFI(root); return; }
  const charts = chartsForCategory(categoryId, state.allCharts);
  const list = h('div', { class: 'list' });
  for (const chart of charts) {
    list.appendChild(h('a', { class: 'row', href: `#/chart/${chart.scenario.key}` }, [
      ...categoryRowContent(chart),
      h('div', { class: 'row-chev' }, '›'),
    ]));
  }
  if (charts.length === 0) {
    list.appendChild(h('div', { class: 'empty' }, 'No charts available.'));
  }
  clear(root);
  root.appendChild(page(cat.title, '#/', [list]));
}

function renderChartDetail(root, scenario) {
  const chart = state.chartByKey.get(scenario.key);
  if (!chart) { renderError(root, `Chart not found: ${scenario.key}`); return; }

  let revealed = false;
  const grid = buildGrid({ interactive: false });

  function repaint() {
    for (const cell of grid.children) {
      const hand = cell.dataset.hand;
      const ca = revealed ? chartAction(chart, hand) : { kind: 'pure', action: 'fold' };
      const { background, fg, outline } = cellFill(state.palette, ca);
      paintCell(cell, background, fg, outline);
    }
  }
  repaint();

  const toggleBtn = h('button', { class: 'btn' }, revealed ? 'Hide' : 'Show');
  toggleBtn.addEventListener('click', () => {
    revealed = !revealed;
    toggleBtn.textContent = revealed ? 'Hide' : 'Show';
    repaint();
  });

  const legend = h('div', { class: 'legend' }, buildChartLegend(chart));

  const practice = h('a', {
    class: 'btn btn-primary',
    href: `#/recall/${chart.scenario.key}`,
  }, 'Practice: Chart Recall');

  const buttons = [toggleBtn, practice];
  // AC4.5: Edit only when a token is configured.
  if (getToken()) {
    buttons.push(h('a', {
      class: 'btn',
      href: `#/edit/${chart.scenario.key}`,
    }, 'Edit'));
  }

  const meta = [];
  if (chart.openSize) meta.push(h('div', { class: 'meta-line' }, `Open size: ${chart.openSize}`));
  if (chart.note) meta.push(h('div', { class: 'meta-line' }, chart.note));

  const back = backHrefForScenario(scenario);
  const body = [
    h('div', { class: 'grid-wrap' }, [grid]),
    legend,
    meta.length ? h('div', { class: 'meta' }, meta) : null,
    h('div', { class: 'actions' }, buttons),
  ].filter(Boolean);

  clear(root);
  root.appendChild(page(scenarioTitle(scenario), back, body));

  state.onPaletteChange = () => {
    repaint();
    const items = buildChartLegend(chart);
    clear(legend);
    for (const i of items) legend.appendChild(i);
  };
}

function backHrefForScenario(scenario) {
  if (scenario.kind === 'rfi') return '#/rfi';
  if (scenario.kind === 'defense') return `#/category/${scenario.hero.toLowerCase()}Defense`;
  if (scenario.kind === 'vs3bet') return `#/category/${scenario.hero.toLowerCase()}Vs3bet`;
  if (scenario.kind === 'vs4bet') return `#/category/${scenario.hero.toLowerCase()}Vs4bet`;
  return '#/';
}

function renderUnifiedRFI(root) {
  if (!state.unified) {
    renderError(root, 'Unified RFI chart requires UTG, MP, CO, BTN RFI charts.');
    return;
  }
  const unified = state.unified;
  let revealed = true;
  const grid = buildGrid({ interactive: false });

  function repaint() {
    for (const cell of grid.children) {
      const hand = cell.dataset.hand;
      const ring = revealed ? unified.ringFor(hand) : null;
      const fill = revealed
        ? colorForRing(state.rfiPalette, ring)
        : (state.rfiPalette.fold ?? resolveAutoFoldColor());
      paintCell(cell, fill, foregroundOn(fill), false);
    }
  }
  repaint();

  const toggle = h('button', { class: 'btn' }, revealed ? 'Hide' : 'Show');
  toggle.addEventListener('click', () => {
    revealed = !revealed;
    toggle.textContent = revealed ? 'Hide' : 'Show';
    repaint();
  });

  const legend = h('div', { class: 'legend' });
  function buildRFILegend() {
    const items = [
      ['UTG',    state.rfiPalette.utg,   unified.cumulativeFraction('UTG')],
      ['MP',     state.rfiPalette.mp,    unified.cumulativeFraction('MP')],
      ['CO',     state.rfiPalette.co,    unified.cumulativeFraction('CO')],
      ['BTN/SB', state.rfiPalette.btnSb, unified.cumulativeFraction('BTN')],
    ];
    clear(legend);
    for (const [label, color, frac] of items) {
      legend.appendChild(legendItemEl(color, label, frac));
    }
  }
  buildRFILegend();

  // AC5.4: position buttons now link to the per-position RFI chart view
  // (which has its own Practice and (with a token) Edit buttons).
  const positions = ['UTG','MP','CO','BTN','SB']
    .filter(p => state.chartByKey.has(`rfi.${p.toLowerCase()}`));
  const positionsRow = h('div', { class: 'practice-group' }, [
    h('div', { class: 'practice-label' }, 'Open a position RFI chart:'),
    h('div', { class: 'practice-row' },
      positions.map(p => h('a', {
        class: 'btn',
        href: `#/chart/rfi.${p.toLowerCase()}`,
      }, p))
    ),
  ]);

  const rfiColors = h('a', { class: 'btn', href: '#/rfi-colors/rfi' }, 'Edit RFI Colors');

  clear(root);
  root.appendChild(page('RFI', '#/', [
    h('div', { class: 'grid-wrap' }, [grid]),
    legend,
    h('div', { class: 'actions' }, [toggle, rfiColors]),
    positionsRow,
  ]));

  state.onPaletteChange = () => { repaint(); buildRFILegend(); };
}

function paintingPromptFor(chart) {
  if (chart.scenario.kind === 'rfi') return 'Tap the hands you would open.';
  return 'Tap cells with the action you would take.';
}

function renderRecall(root, scenario) {
  const chart = state.chartByKey.get(scenario.key);
  if (!chart) { renderError(root, `Chart not found: ${scenario.key}`); return; }

  const options = recallPaletteFor(chart);
  let selectedIdx = 0;
  const painted = new Map();
  let phase = 'painting';
  let gradeResult = null;

  const grid = buildGrid({
    interactive: true,
    isEraseStart(hand) {
      const existing = painted.get(hand);
      const selected = options[selectedIdx].answer;
      return !!existing && actionsEqual(existing, selected);
    },
    onPaint(hand, erase) {
      if (phase !== 'painting') return;
      if (erase) painted.delete(hand);
      else painted.set(hand, options[selectedIdx].answer);
      repaintCell(hand);
      updateCount();
      submitBtn.toggleAttribute('disabled', painted.size === 0);
    },
  });

  function paintSingle(cell) {
    const hand = cell.dataset.hand;
    if (phase === 'graded') {
      const g = gradeResult.grades.get(hand);
      const { fill, fg } = gradedCellColors(g, chart, hand);
      // Graded cells stay solid (AC17.2): no outline, no split.
      paintCell(cell, fill, fg, false);
      return;
    }
    const answer = painted.get(hand);
    if (answer) {
      const { background, fg, outline } = cellFill(state.palette, answer);
      paintCell(cell, background, fg, outline);
    } else {
      const fill = foldColor();
      paintCell(cell, fill, foregroundOn(fill), false);
    }
  }
  function repaintCell(hand) {
    const cell = grid.querySelector(`.cell[data-hand="${hand}"]`);
    if (cell) paintSingle(cell);
  }
  function repaintAll() { for (const cell of grid.children) paintSingle(cell); }
  repaintAll();

  const prompt = h('div', { class: 'prompt' }, paintingPromptFor(chart));

  const paletteRow = h('div', { class: 'palette-row' });
  function renderPaletteRow() {
    clear(paletteRow);
    options.forEach((o, i) => {
      const btn = h('button', {
        class: 'palette-btn' + (i === selectedIdx ? ' selected' : ''),
        'aria-pressed': i === selectedIdx ? 'true' : 'false',
      }, [
        h('span', {
          class: 'swatch',
          style: `background: ${cellFill(state.palette, o.answer).background}`,
        }),
        h('span', { class: 'palette-label' }, o.label),
      ]);
      btn.addEventListener('click', () => {
        selectedIdx = i;
        renderPaletteRow();
      });
      paletteRow.appendChild(btn);
    });
  }
  renderPaletteRow();

  const countEl = h('span', { class: 'count-num' }, '0');
  function updateCount() { countEl.textContent = String(painted.size); }

  const clearBtn = h('button', { class: 'btn' }, 'Clear');
  clearBtn.addEventListener('click', () => {
    if (phase !== 'painting') return;
    painted.clear();
    repaintAll();
    updateCount();
    submitBtn.toggleAttribute('disabled', true);
  });
  const submitBtn = h('button', { class: 'btn btn-primary', disabled: true }, 'Submit');
  submitBtn.addEventListener('click', () => {
    if (phase !== 'painting' || painted.size === 0) return;
    gradeResult = gradeChart(painted, chart);
    phase = 'graded';
    repaintAll();
    renderFooter();
    renderHeader();
  });
  const retryBtn = h('button', { class: 'btn btn-primary' }, 'Try again');
  retryBtn.addEventListener('click', () => {
    painted.clear();
    phase = 'painting';
    gradeResult = null;
    repaintAll();
    updateCount();
    submitBtn.toggleAttribute('disabled', true);
    renderFooter();
    renderHeader();
  });

  const header = h('div', { class: 'recall-header' });
  const footer = h('div', { class: 'recall-footer' });
  function renderHeader() {
    clear(header);
    if (phase === 'painting') { header.appendChild(prompt); return; }
    const r = gradeResult;
    const chips = [];
    if (r.missed > 0) chips.push(h('span', { class: 'chip chip-missed' }, `${r.missed} missed`));
    if (r.wrongAction > 0) chips.push(h('span', { class: 'chip chip-wrong' }, `${r.wrongAction} wrong`));
    if (r.wrongExtra > 0) chips.push(h('span', { class: 'chip chip-extra' }, `${r.wrongExtra} extra`));
    if (chips.length === 0) chips.push(h('span', { class: 'chip chip-perfect' }, 'Perfect'));
    header.appendChild(h('div', { class: 'grade' }, chips));
  }
  function renderFooter() {
    clear(footer);
    if (phase === 'painting') {
      footer.appendChild(h('div', { class: 'actions' }, [clearBtn, submitBtn]));
      footer.appendChild(h('div', { class: 'palette-wrap' }, [
        paletteRow,
        h('span', { class: 'count-wrap' }, [h('span', {}, 'Painted: '), countEl]),
      ]));
    } else {
      footer.appendChild(h('div', { class: 'actions' }, [retryBtn]));
    }
  }
  renderHeader();
  renderFooter();

  clear(root);
  root.appendChild(page(scenarioTitle(scenario) + ' · Recall', `#/chart/${scenario.key}`, [
    header,
    h('div', { class: 'grid-wrap' }, [grid]),
    footer,
  ]));

  state.onPaletteChange = () => {
    renderPaletteRow();
    repaintAll();
  };
}

function gradedCellColors(grade, chart, hand) {
  const foldFill = foldColor();
  switch (grade) {
    case 'correct': {
      const exp = chartAction(chart, hand);
      if (exp.kind === 'pure' && exp.action === 'fold') {
        return { fill: foldFill, fg: foregroundOn(foldFill) };
      }
      const green = '#38B359';
      return { fill: green, fg: foregroundOn(green) };
    }
    case 'missed':      return { fill: '#F39E1A', fg: '#ffffff' };
    case 'wrongAction': return { fill: '#F5CC33', fg: '#111111' };
    case 'wrongExtra':  return { fill: '#EB4D4D', fg: '#ffffff' };
    default:            return { fill: foldFill, fg: foregroundOn(foldFill) };
  }
}

// ------------------- Colors -------------------

function tokenGate() { return !!getToken(); }

function setPaletteSlot(key, value) {
  state.palette = { ...state.palette, [key]: value };
  state.onPaletteChange?.();
}

function setRFIPaletteSlot(key, value) {
  state.rfiPalette = { ...state.rfiPalette, [key]: value };
  state.onPaletteChange?.();
}

function paletteDirty() {
  return !palettesEqual(
    { palette: state.palette, rfiPalette: state.rfiPalette },
    { palette: state.savedPalette, rfiPalette: state.savedRfiPalette },
  );
}

function revertPaletteToSaved() {
  state.palette = { ...state.savedPalette };
  state.rfiPalette = { ...state.savedRfiPalette };
}

function renderColorsPage(root) {
  const connected = tokenGate();
  const note = connected
    ? h('div', { class: 'meta' }, 'Preview changes locally. Save to GitHub to apply them everywhere.')
    : h('div', { class: 'error' }, 'Colors come from the repo. Add a GitHub token to change them.');

  // Inline error box, shown above the actions. Hidden by default (AC11.7
  // palette variant: 401/403 and 409/422 errors appear here, not only as
  // toasts).
  const errorBox = h('div', { class: 'error', hidden: true, 'aria-live': 'polite' });

  const resetBtn = h('button', { class: 'btn btn-destructive' }, 'Reset to defaults');
  const saveBtn = h('button', {
    class: 'btn btn-primary',
    disabled: !connected || !paletteDirty(),
  }, 'Save colors to GitHub');

  function updateSaveDisabled() {
    saveBtn.disabled = !connected || !paletteDirty();
  }

  resetBtn.addEventListener('click', () => {
    // AC7.2: "Reset to defaults" sets the built-in defaults as the unsaved
    // preview.
    state.palette = { ...DEFAULT_PALETTE };
    state.rfiPalette = { ...DEFAULT_RFI_PALETTE };
    // Re-render current page to refresh pickers and save-button state.
    renderColorsPage(root);
  });
  saveBtn.addEventListener('click', () =>
    savePaletteToGitHub(root, saveBtn, errorBox, 'colors'));

  const actionsRow = h('div', { class: 'actions' }, [resetBtn, saveBtn]);

  const rows = h('div', { class: 'form' }, [
    note,
    sectionHeader('Pure actions'),
    colorRow('Fold',   'fold', !connected),
    colorRow('Call',   'call', !connected),
    colorRow('Open',   'open', !connected),
    colorRow('3-Bet',  '3bet', !connected),
    colorRow('4-Bet',  '4bet', !connected),
    colorRow('All-In', '5bet', !connected),
    // AC17.5: mixed-action pickers removed. Mixed cells are drawn as a
    // 50/50 split of the two pure legs, so the four mixed slots have no
    // visual effect. Their keys stay in palette.json unchanged.
    h('div', { class: 'actions' }, [
      h('a', { class: 'btn', href: '#/rfi-colors' }, 'Edit RFI Colors →'),
    ]),
    errorBox,
    actionsRow,
  ]);
  clear(root);
  root.appendChild(page('Colors', '#/', [rows]));

  // AC12.3/12.4: re-evaluate the save button after every palette change
  // (pickers, Fold "Auto", etc.) so it enables as soon as something differs
  // from the saved palette.
  state.onPaletteChange = updateSaveDisabled;
}

function colorRow(label, key, disabled) {
  const current = state.palette[key] ?? resolveAutoFoldColor();
  const picker = h('input', { type: 'color', value: current });
  if (disabled) picker.setAttribute('disabled', '');
  picker.addEventListener('input', () => setPaletteSlot(key, picker.value));
  const row = h('div', { class: 'form-row' }, [
    h('span', { class: 'form-label' }, label),
    picker,
    key === 'fold' ? (() => {
      const btn = h('button', { class: 'btn btn-small' }, 'Auto');
      if (disabled) btn.setAttribute('disabled', '');
      btn.addEventListener('click', () => {
        setPaletteSlot('fold', null);
        picker.value = resolveAutoFoldColor();
      });
      return btn;
    })() : null,
  ].filter(Boolean));
  return row;
}

function rfiColorRow(label, key, disabled) {
  const current = state.rfiPalette[key] ?? resolveAutoFoldColor();
  const picker = h('input', { type: 'color', value: current });
  if (disabled) picker.setAttribute('disabled', '');
  picker.addEventListener('input', () => setRFIPaletteSlot(key, picker.value));
  return h('div', { class: 'form-row' }, [
    h('span', { class: 'form-label' }, label),
    picker,
  ]);
}

function sectionHeader(label) {
  return h('div', { class: 'section-header' }, label);
}

function renderRFIColorsPage(root, from) {
  const connected = tokenGate();
  const backHref = from === 'rfi' ? '#/rfi' : '#/colors';
  const note = connected
    ? h('div', { class: 'meta' }, 'Preview changes locally. Save to GitHub to apply them everywhere.')
    : h('div', { class: 'error' }, 'Colors come from the repo. Add a GitHub token to change them.');

  // Inline error box above the actions (AC11.7 palette variant / AC12.3).
  const errorBox = h('div', { class: 'error', hidden: true, 'aria-live': 'polite' });

  const resetBtn = h('button', { class: 'btn btn-destructive' }, 'Reset to defaults');
  resetBtn.addEventListener('click', () => {
    state.rfiPalette = { ...DEFAULT_RFI_PALETTE };
    renderRFIColorsPage(root, from);
  });
  const saveBtn = h('button', {
    class: 'btn btn-primary',
    disabled: !connected || !paletteDirty(),
  }, 'Save colors to GitHub');
  saveBtn.addEventListener('click', () =>
    savePaletteToGitHub(root, saveBtn, errorBox, 'rfi', from));

  function updateSaveDisabled() {
    saveBtn.disabled = !connected || !paletteDirty();
  }

  const rows = h('div', { class: 'form' }, [
    note,
    sectionHeader('RFI ring colors'),
    rfiColorRow('UTG',    'utg',   !connected),
    rfiColorRow('MP',     'mp',    !connected),
    rfiColorRow('CO',     'co',    !connected),
    rfiColorRow('BTN/SB', 'btnSb', !connected),
    rfiColorRow('Fold',   'fold',  !connected),
    errorBox,
    h('div', { class: 'actions' }, [resetBtn, saveBtn]),
  ]);
  clear(root);
  root.appendChild(page('Edit RFI Colors', backHref, [rows]));

  // AC12.3/12.4: re-evaluate the save button after every palette change.
  state.onPaletteChange = updateSaveDisabled;
}

async function savePaletteToGitHub(root, button, errorBox, which, from) {
  // AC: ignore a second invocation while one is already in flight; don't
  // rely only on the button's disabled attribute.
  if (paletteSaveInFlight) return;
  const token = getToken();
  if (!token) {
    toast('Add a GitHub token first', { kind: 'error' });
    location.hash = '#/github';
    return;
  }
  if (!paletteDirty()) return;
  clearInlineError(errorBox);
  paletteSaveInFlight = true;
  button.setAttribute('disabled', '');
  const prevLabel = button.textContent;
  button.textContent = 'Saving…';
  try {
    const { sha } = await getFile(token, PALETTE_REPO_PATH);
    const text = serializePaletteFile(state.palette, state.rfiPalette);
    await putFile(token, PALETTE_REPO_PATH, {
      message: 'Update colors from web app',
      text,
      sha,
    });
    recordPendingWrite(PALETTE_APP_PATH, text);
    state.savedPalette = { ...state.palette };
    state.savedRfiPalette = { ...state.rfiPalette };
    toast('Saved to GitHub — live on other devices in about a minute', { kind: 'success' });
    paletteSaveInFlight = false;
    // Re-render whichever colors page we were on so the save button
    // disables.
    if (which === 'rfi') renderRFIColorsPage(root, from);
    else renderColorsPage(root);
  } catch (err) {
    paletteSaveInFlight = false;
    button.removeAttribute('disabled');
    button.textContent = prevLabel;
    handleGitHubError(err, { context: 'palette', inlineBox: errorBox });
  }
}

function handleGitHubError(err, { context = 'other', inlineBox = null } = {}) {
  const kind = err?.kind || 'other';
  if (kind === 'conflict') {
    // AC11.7: the chart-editor variant message is EXACT.
    const msg = context === 'editor'
      ? 'This chart changed on GitHub since you opened it. Reload the editor and re-apply your edit.'
      : context === 'palette'
      ? 'Colors changed on GitHub since you opened this page. Reload and re-apply your change.'
      : 'This file changed on GitHub since you opened it. Reload and try again.';
    toast(msg, { kind: 'error', ttl: 7000 });
    if (inlineBox) setInlineError(inlineBox, [msg]);
    return;
  }
  if (kind === 'unauthorized' || kind === 'forbidden' || kind === 'noWrite') {
    // AC11.7: 401/403 must appear INLINE on the page (with a link to the
    // GitHub settings page) and not only as a toast.
    const lead = tokenErrorLead(kind);
    toast(lead + 'GitHub settings.', { kind: 'error', ttl: 9000 });
    if (inlineBox) setInlineError(inlineBox, tokenRejectedChildren(lead));
    return;
  }
  if (kind === 'network') {
    const msg = "Couldn't reach GitHub. Edits are kept.";
    toast(msg, { kind: 'error', ttl: 7000 });
    if (inlineBox) setInlineError(inlineBox, [msg]);
    return;
  }
  const msg = err?.message || 'Save failed';
  toast(msg, { kind: 'error', ttl: 7000 });
  if (inlineBox) setInlineError(inlineBox, [msg]);
}

// ------------------- GitHub settings -------------------

function renderGitHubPage(root) {
  const existing = getToken();
  const explain = h('p', { class: 'prose' },
    'A GitHub token lets this app save edits (charts and colors) back to the repo. ' +
    'Create a fine-grained personal access token with access limited to the ' +
    'ranges_trainer repo, Repository permissions → Contents: Read and write, and nothing else.');
  const createLink = h('p', { class: 'prose dim' }, [
    'Create one at: ',
    h('span', { class: 'mono' }, 'github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token'),
  ]);

  const input = h('input', {
    type: 'password',
    autocomplete: 'off',
    autocapitalize: 'off',
    autocorrect: 'off',
    spellcheck: 'false',
    placeholder: 'github_pat_…',
    class: 'token-input',
    'aria-label': 'GitHub token',
  });
  const status = h('div', { class: 'token-status' });

  function renderStatus() {
    clear(status);
    const t = getToken();
    if (t) {
      const last4 = t.length >= 4 ? t.slice(-4) : t;
      status.appendChild(h('div', { class: 'meta' },
        `Connected — can write to ranges_trainer (last 4: •••• ${last4})`));
    }
  }
  renderStatus();

  const saveBtn = h('button', { class: 'btn btn-primary' }, 'Save & test');
  saveBtn.addEventListener('click', async () => {
    const token = input.value.trim();
    if (!token) {
      toast('Enter a token first', { kind: 'error' });
      return;
    }
    saveBtn.setAttribute('disabled', '');
    saveBtn.textContent = 'Testing…';
    try {
      await testConnection(token);
      // GET /repos reports the account's permissions, not the token's, so
      // also confirm the token itself can write (changes nothing).
      await testWriteAccess(token, PALETTE_REPO_PATH);
      setToken(token);
      input.value = '';                          // AC10.4: clear from DOM
      toast('Connected — can write to ranges_trainer', { kind: 'success' });
      // Re-render so "Remove token" appears immediately now that we have
      // a token (and the home-page hint will update on next visit).
      renderGitHubPage(root);
    } catch (err) {
      saveBtn.removeAttribute('disabled');
      saveBtn.textContent = 'Save & test';
      // AC10.2: failure does NOT store the token.
      const msg = err instanceof GitHubError
        ? `Can't use that token: ${err.message}`
        : `Can't use that token: ${err?.message || err}`;
      toast(msg, { kind: 'error', ttl: 7000 });
    }
  });

  const removeBtn = h('button', { class: 'btn btn-destructive' }, 'Remove token');
  removeBtn.addEventListener('click', () => {
    if (!getToken()) return;
    if (!confirm('Remove the stored GitHub token?')) return;
    clearToken();
    toast('Token removed', { kind: 'info' });
    // Re-render so "Remove token" disappears immediately.
    renderGitHubPage(root);
  });

  const buttons = h('div', { class: 'actions' }, [saveBtn, existing ? removeBtn : null].filter(Boolean));

  const form = h('div', { class: 'form' }, [
    explain,
    createLink,
    h('div', { class: 'form-row' }, [
      h('span', { class: 'form-label' }, 'Token'),
      input,
    ]),
    buttons,
    status,
  ]);
  clear(root);
  root.appendChild(page('GitHub', '#/', [form]));
}

// ------------------- Editor -------------------

function actionsForChartType(chartType) {
  // AC11.3: paint palette = every valid action for the chart type, plus Fold.
  if (chartType === 'rfi') return [
    { label: 'Open', answer: { kind: 'pure', action: 'open' } },
    { label: 'Fold', answer: { kind: 'pure', action: 'fold' } },
  ];
  if (chartType === 'defense') return [
    { label: '3-Bet',       answer: { kind: 'pure', action: '3bet' } },
    { label: '3-Bet/Call',  answer: { kind: 'mixed', aggressive: '3bet', passive: 'call' } },
    { label: '3-Bet/Fold',  answer: { kind: 'mixed', aggressive: '3bet', passive: 'fold' } },
    { label: 'Call',        answer: { kind: 'pure', action: 'call' } },
    { label: 'Fold',        answer: { kind: 'pure', action: 'fold' } },
  ];
  if (chartType === 'vs3bet') return [
    { label: '4-Bet',       answer: { kind: 'pure', action: '4bet' } },
    { label: '4-Bet/Call',  answer: { kind: 'mixed', aggressive: '4bet', passive: 'call' } },
    { label: 'Call',        answer: { kind: 'pure', action: 'call' } },
    { label: 'Fold',        answer: { kind: 'pure', action: 'fold' } },
  ];
  if (chartType === 'vs4bet') return [
    { label: 'All-In',      answer: { kind: 'pure', action: '5bet' } },
    { label: 'All-In/Call', answer: { kind: 'mixed', aggressive: '5bet', passive: 'call' } },
    { label: 'Call',        answer: { kind: 'pure', action: 'call' } },
    { label: 'Fold',        answer: { kind: 'pure', action: 'fold' } },
  ];
  return [{ label: 'Fold', answer: { kind: 'pure', action: 'fold' } }];
}

function entriesFromChart(chart) {
  const map = new Map();
  for (const [h, ca] of chart.entries) map.set(h, { ...ca });
  return map;
}

function labelForAction(ca) {
  if (!ca || (ca.kind === 'pure' && ca.action === 'fold')) return 'Fold';
  if (ca.kind === 'pure') {
    if (ca.action === 'open') return 'Open';
    if (ca.action === '3bet') return '3-Bet';
    if (ca.action === '4bet') return '4-Bet';
    if (ca.action === '5bet') return 'All-In';
    if (ca.action === 'call') return 'Call';
  }
  if (ca.kind === 'mixed') {
    if (ca.aggressive === '3bet' && ca.passive === 'call') return '3-Bet/Call';
    if (ca.aggressive === '3bet' && ca.passive === 'fold') return '3-Bet/Fold';
    if (ca.aggressive === '4bet' && ca.passive === 'call') return '4-Bet/Call';
    if (ca.aggressive === '5bet' && ca.passive === 'call') return 'All-In/Call';
  }
  return '?';
}

function pureFold() { return { kind: 'pure', action: 'fold' }; }
function isFold(ca) { return !ca || (ca.kind === 'pure' && ca.action === 'fold'); }

async function renderEditor(root, scenario) {
  // Guard: without a token, the route shows a message linking to the token
  // page (AC11.1).
  const token = getToken();
  if (!token) {
    clear(root);
    root.appendChild(page('Editor', `#/chart/${scenario.key}`, [
      h('div', { class: 'error' }, 'An editor needs a GitHub token.'),
      h('div', { class: 'actions' }, [
        h('a', { class: 'btn btn-primary', href: '#/github' }, 'Add a token'),
      ]),
    ]));
    return;
  }

  const inMemory = state.chartByKey.get(scenario.key);
  if (!inMemory) { renderError(root, `Chart not found: ${scenario.key}`); return; }

  // Loading state
  clear(root);
  root.appendChild(page(`Edit ${scenarioTitle(scenario)}`, `#/chart/${scenario.key}`, [
    h('div', { class: 'loading' }, 'Loading latest version from GitHub…'),
  ]));

  const appPath = state.pathByScenarioKey.get(scenario.key);
  if (!appPath) { renderError(root, `Unknown chart path for ${scenario.key}`); return; }
  const repoPath = appPathToRepoPath(appPath);

  // AC: capture the route hash before the await. If the user navigated
  // away by the time getFile resolves/rejects, abort without rendering
  // and without installing an unsaved-changes guard.
  const capturedHash = location.hash;

  let sha, originalText, originalChart;
  try {
    const got = await getFile(token, repoPath);
    if (location.hash !== capturedHash) return;
    sha = got.sha;
    originalText = got.text;
    originalChart = parseChartText(appPath, originalText);
  } catch (err) {
    if (location.hash !== capturedHash) return;
    clear(root);
    const isAuth = err instanceof GitHubError && (err.kind === 'unauthorized' || err.kind === 'forbidden');
    const body = [];
    if (isAuth) {
      // Inline, with a link to the GitHub settings page (text nodes only).
      body.push(h('div', { class: 'error' }, tokenRejectedChildren(tokenErrorLead(err.kind))));
      body.push(h('div', { class: 'actions' }, [
        h('a', { class: 'btn btn-primary', href: '#/github' }, 'Open GitHub settings'),
      ]));
    } else {
      body.push(h('div', { class: 'error' },
        err instanceof GitHubError
          ? `Couldn't open the latest version from GitHub: ${err.message}`
          : `Couldn't open the latest version: ${err?.message || err}`));
    }
    root.appendChild(page(`Edit ${scenarioTitle(scenario)}`, `#/chart/${scenario.key}`, body));
    return;
  }

  // Detect divergence between what the app loaded and what GitHub currently
  // has (deploy lag). We use the GitHub version as the start state (AC11.2).
  const divergedFromMemory = !sameEntries(inMemory.entries, originalChart.entries);

  const chartType = originalChart.scenario.kind;
  const options = actionsForChartType(chartType);
  let selectedIdx = 0;

  const editedEntries = entriesFromChart(originalChart); // hand → ChartAction (may be pure fold if we add one explicitly)
  const originalEntries = entriesFromChart(originalChart);

  function entryAt(hand) {
    const ca = editedEntries.get(hand);
    return ca || pureFold();
  }
  function origAt(hand) {
    const ca = originalEntries.get(hand);
    return ca || pureFold();
  }
  function isChanged(hand) { return !actionsEqual(entryAt(hand), origAt(hand)); }

  function countChanged() {
    let n = 0;
    for (const hand of allHands()) if (isChanged(hand)) n++;
    return n;
  }

  const grid = buildGrid({
    interactive: true,
    isEraseStart(hand) {
      // Starting on a cell already set to the selected option sets the
      // gesture to Fold (same erase-on-start rule as recall).
      const current = entryAt(hand);
      const sel = options[selectedIdx].answer;
      return actionsEqual(current, sel);
    },
    onPaint(hand, erase) {
      const sel = erase ? pureFold() : options[selectedIdx].answer;
      if (isFold(sel)) editedEntries.delete(hand);
      else editedEntries.set(hand, sel);
      paintEditorCell(grid.querySelector(`.cell[data-hand="${hand}"]`), hand);
      updateCounter();
    },
  });

  function paintEditorCell(cell, hand) {
    if (!cell) return;
    const ca = entryAt(hand);
    const { background, fg, outline } = cellFill(state.palette, ca);
    paintCell(cell, background, fg, outline);
    cell.classList.toggle('changed', isChanged(hand));
  }
  function paintAll() {
    for (const cell of grid.children) paintEditorCell(cell, cell.dataset.hand);
  }
  paintAll();

  const paletteRow = h('div', { class: 'palette-row' });
  function renderPaletteRow() {
    clear(paletteRow);
    options.forEach((o, i) => {
      const btn = h('button', {
        class: 'palette-btn' + (i === selectedIdx ? ' selected' : ''),
        'aria-pressed': i === selectedIdx ? 'true' : 'false',
      }, [
        h('span', {
          class: 'swatch',
          style: `background: ${cellFill(state.palette, o.answer).background}`,
        }),
        h('span', { class: 'palette-label' }, o.label),
      ]);
      btn.addEventListener('click', () => {
        selectedIdx = i;
        renderPaletteRow();
      });
      paletteRow.appendChild(btn);
    });
  }
  renderPaletteRow();

  const counter = h('span', { class: 'count-num' }, '0');
  function updateCounter() {
    const n = countChanged();
    counter.textContent = String(n);
    saveBtn.toggleAttribute('disabled', n === 0);
    revertBtn.toggleAttribute('disabled', n === 0);
  }

  const revertBtn = h('button', { class: 'btn', disabled: true }, 'Revert');
  revertBtn.addEventListener('click', () => {
    for (const h of allHands()) editedEntries.delete(h);
    for (const [k, v] of originalEntries) editedEntries.set(k, { ...v });
    paintAll();
    updateCounter();
  });

  const saveBtn = h('button', { class: 'btn btn-primary', disabled: true }, 'Save');
  // Inline error box above the actions (AC11.7). Shown only on error.
  const errorBox = h('div', { class: 'error', hidden: true, 'aria-live': 'polite' });
  saveBtn.addEventListener('click', () => openSaveConfirm({
    scenario, appPath, repoPath, originalText, originalEntries, editedEntries, sha, saveBtn, options, errorBox,
  }));

  const divergedNote = divergedFromMemory
    ? h('div', { class: 'meta' }, 'Loaded the latest version from GitHub.')
    : null;

  const promptText = chartType === 'rfi'
    ? 'Tap cells to toggle open/fold.'
    : 'Pick an action below, then paint cells.';

  clear(root);
  root.appendChild(page(`Edit ${scenarioTitle(scenario)}`, `#/chart/${scenario.key}`, [
    divergedNote,
    h('div', { class: 'prompt' }, promptText),
    h('div', { class: 'grid-wrap' }, [grid]),
    h('div', { class: 'palette-wrap' }, [
      paletteRow,
      h('span', { class: 'count-wrap' }, [h('span', {}, 'Changed: '), counter]),
    ]),
    errorBox,
    h('div', { class: 'actions' }, [revertBtn, saveBtn]),
  ].filter(Boolean)));

  setUnsavedGuard(location.hash, () => countChanged() > 0);
  state.onPaletteChange = () => { renderPaletteRow(); paintAll(); };
}

function sameEntries(a, b) {
  const keys = new Set([...a.keys(), ...b.keys()]);
  for (const k of keys) {
    const x = a.get(k) || pureFold();
    const y = b.get(k) || pureFold();
    if (!actionsEqual(x, y)) return false;
  }
  return true;
}

function openSaveConfirm(ctx) {
  const { scenario, appPath, repoPath, originalText, originalEntries, editedEntries, sha, saveBtn, options, errorBox } = ctx;
  const diffsByLabel = new Map();
  for (const hand of allHands()) {
    const o = originalEntries.get(hand) || pureFold();
    const e = editedEntries.get(hand) || pureFold();
    if (actionsEqual(o, e)) continue;
    const label = labelForAction(e);
    const arr = diffsByLabel.get(label) || [];
    arr.push(hand);
    diffsByLabel.set(label, arr);
  }

  // Order groups by palette order so "Open: +… · Fold: +…" reads naturally.
  const order = options.map(o => o.label);
  const groups = [...diffsByLabel.entries()]
    .sort((a, b) => order.indexOf(a[0]) - order.indexOf(b[0]));
  const summary = groups
    .map(([label, hands]) => `${label}: ${hands.map(h => '+' + h).join(', ')}`)
    .join(' · ');

  const modal = h('div', { class: 'modal-backdrop' }, [
    h('div', { class: 'modal' }, [
      h('h2', { class: 'modal-title' }, `Save ${scenarioTitle(scenario)}?`),
      h('p', { class: 'modal-body' }, summary || 'No changes.'),
      h('div', { class: 'actions modal-actions' }, [
        (() => {
          const b = h('button', { class: 'btn' }, 'Cancel');
          b.addEventListener('click', () => modal.remove());
          return b;
        })(),
        (() => {
          const b = h('button', { class: 'btn btn-primary' }, 'Commit');
          b.addEventListener('click', async () => {
            // AC: ignore a second invocation while one is already in
            // flight; don't rely only on the button's disabled attribute.
            if (editorCommitInFlight) return;
            editorCommitInFlight = true;
            clearInlineError(errorBox);
            b.setAttribute('disabled', ''); b.textContent = 'Saving…';
            saveBtn.setAttribute('disabled', '');
            try {
              const text = chartToFileJSON(originalText, editedEntries);
              // Validate before pushing: must parse and buildChart (AC11.6).
              const validated = buildChart(JSON.parse(text));
              const token = getToken();
              await putFile(token, repoPath, {
                message: `Edit ${scenarioTitle(scenario)} from web app`,
                text,
                sha,
              });
              recordPendingWrite(appPath, text);
              // Apply the new chart in memory so the browser sees the edit
              // immediately (AC11.6).
              state.chartTextByPath.set(appPath, text);
              applyChartInMemory(validated);
              clearUnsavedGuard();
              modal.remove();
              toast('Saved to GitHub — live on other devices in about a minute', { kind: 'success', ttl: 6000 });
              editorCommitInFlight = false;
              location.hash = `#/chart/${scenario.key}`;
            } catch (err) {
              editorCommitInFlight = false;
              b.removeAttribute('disabled'); b.textContent = 'Commit';
              saveBtn.removeAttribute('disabled');
              // AC11.7: 401/403 and 409/422 render INLINE on the editor
              // page (not only as toasts). Close the modal so the user can
              // see the inline message above the actions.
              modal.remove();
              handleGitHubError(err, { context: 'editor', inlineBox: errorBox });
            }
          });
          return b;
        })(),
      ]),
    ]),
  ]);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
  document.body.appendChild(modal);
}

function applyChartInMemory(chart) {
  const key = chart.scenario.key;
  const idx = state.allCharts.findIndex(c => c.scenario.key === key);
  if (idx >= 0) state.allCharts[idx] = chart;
  else state.allCharts.push(chart);
  state.chartByKey.set(key, chart);
  state.unified = unifiedRFI(state.allCharts);
}

// ------------------- Router -------------------

function parseHash() {
  const h = location.hash || '';
  const trimmed = h.replace(/^#\/?/, '');
  if (!trimmed) return { name: 'home' };
  const parts = trimmed.split('/').filter(Boolean);
  switch (parts[0]) {
    case 'rfi':         return { name: 'rfi' };
    case 'colors':      return { name: 'colors' };
    case 'rfi-colors':  return { name: 'rfiColors', from: parts[1] };
    case 'category':    return { name: 'category', id: parts[1] };
    case 'chart':       return { name: 'chart', key: parts.slice(1).join('/') };
    case 'recall':      return { name: 'recall', key: parts.slice(1).join('/') };
    case 'edit':        return { name: 'edit', key: parts.slice(1).join('/') };
    case 'github':      return { name: 'github' };
    default:            return { name: 'home' };
  }
}

function route(root) {
  state.onPaletteChange = null;
  // Clear any stray modal backdrop (e.g. the editor's save-confirm modal)
  // that could survive a hash-driven navigation.
  for (const m of document.body.querySelectorAll('.modal-backdrop')) {
    m.remove();
  }
  // Any navigation to a non-colors page reverts the preview to the last
  // saved palette (AC12.3). The editor itself does not touch the palette.
  const r = parseHash();
  if (r.name !== 'colors' && r.name !== 'rfiColors') {
    if (paletteDirty()) revertPaletteToSaved();
  }
  if (r.name !== 'edit') {
    clearUnsavedGuard();
  }
  if (state.loadError) {
    renderError(root, state.loadError.message || String(state.loadError));
    return;
  }
  switch (r.name) {
    case 'home':      renderHome(root); break;
    case 'rfi':       renderUnifiedRFI(root); break;
    case 'colors':    renderColorsPage(root); break;
    case 'rfiColors': renderRFIColorsPage(root, r.from); break;
    case 'category':  renderCategory(root, r.id); break;
    case 'github':    renderGitHubPage(root); break;
    case 'chart': {
      const sc = parseScenarioKey(r.key || '');
      if (!sc) { renderError(root, `Invalid scenario key: ${r.key}`); return; }
      renderChartDetail(root, sc);
      break;
    }
    case 'recall': {
      const sc = parseScenarioKey(r.key || '');
      if (!sc) { renderError(root, `Invalid scenario key: ${r.key}`); return; }
      renderRecall(root, sc);
      break;
    }
    case 'edit': {
      const sc = parseScenarioKey(r.key || '');
      if (!sc) { renderError(root, `Invalid scenario key: ${r.key}`); return; }
      renderEditor(root, sc);
      break;
    }
    default: renderHome(root);
  }
}

function handleHashChange(root) {
  if (suppressNextHashChange) { suppressNextHashChange = false; return; }
  if (unsavedGuard && location.hash !== unsavedGuard.hash && unsavedGuard.hasChanges()) {
    const ok = confirm('Leave the editor? Your unsaved changes will be lost.');
    if (!ok) {
      // Restore the editor hash without re-rendering. AC11.8: declining keeps
      // the user on the editor.
      suppressNextHashChange = true;
      const target = unsavedGuard.hash;
      // Direct hash assignment; the second firing of hashchange is swallowed
      // by `suppressNextHashChange`.
      try { location.hash = target; } catch {}
      return;
    }
    // Accepted: fall through to route.
    unsavedGuard = null;
  }
  route(root);
}

// ------------------- Boot -------------------

async function fetchText(path) {
  const res = await fetch(path, { cache: 'default' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.text();
}

async function boot() {
  const root = document.getElementById('app');
  clear(root);
  root.appendChild(h('div', { class: 'loading' }, 'Loading charts…'));

  // AC12.2: delete legacy palette localStorage keys on every boot.
  clearOldPaletteKeys();

  try {
    // Fetch deployed texts for charts + palette in parallel.
    const [chartTexts, paletteText] = await Promise.all([
      fetchAllChartTexts(),
      fetchText(`./${PALETTE_APP_PATH}`).catch(() => null),
    ]);

    // Reconcile pending writes (AC14.1).
    const deployed = { ...chartTexts };
    if (paletteText != null) deployed[PALETTE_APP_PATH] = paletteText;
    const pending = loadPendingWrites();
    const { pending: keptPending, overrides } =
      reconcilePendingWrites(pending, deployed, Date.now());
    savePendingWrites(keptPending);

    // Apply overrides and parse.
    const effectiveChartTexts = { ...chartTexts, ...pickCharts(overrides) };
    state.chartTextByPath = new Map(Object.entries(effectiveChartTexts));
    state.allCharts = buildAllCharts(effectiveChartTexts);
    state.chartByKey = new Map(state.allCharts.map(c => [c.scenario.key, c]));
    state.unified = unifiedRFI(state.allCharts);
    state.pathByScenarioKey = new Map();
    for (let i = 0; i < CHART_FILES.length; i++) {
      state.pathByScenarioKey.set(state.allCharts[i].scenario.key, CHART_FILES[i]);
    }

    const paletteSource = overrides[PALETTE_APP_PATH]
      || paletteText
      || null;
    if (paletteSource) {
      const { palette, rfiPalette } = parsePaletteFile(paletteSource);
      state.palette = palette;
      state.rfiPalette = rfiPalette;
      state.savedPalette = { ...palette };
      state.savedRfiPalette = { ...rfiPalette };
    } else {
      state.palette = { ...DEFAULT_PALETTE };
      state.rfiPalette = { ...DEFAULT_RFI_PALETTE };
      state.savedPalette = { ...DEFAULT_PALETTE };
      state.savedRfiPalette = { ...DEFAULT_RFI_PALETTE };
    }
  } catch (err) {
    state.loadError = err;
  }

  route(root);
  window.addEventListener('hashchange', () => handleHashChange(root));

  // Repaint when the system scheme flips if the fold is auto.
  const mql = matchMedia?.('(prefers-color-scheme: dark)');
  mql?.addEventListener?.('change', () => state.onPaletteChange?.());

  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    try { await navigator.serviceWorker.register('./sw.js'); }
    catch (err) { console.warn('SW registration failed:', err); }
  }
}

function pickCharts(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj || {})) {
    if (CHART_FILES.includes(k)) out[k] = v;
  }
  return out;
}

boot();
