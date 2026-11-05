// UI layer: hash routing, DOM building, drag-to-paint, and all views.
// Pure logic lives in domain.js; palettes in colors.js. This module
// touches the DOM.

import {
  CATEGORIES, GRID_SIZE, TOTAL_COMBOS,
  allHands, handAt, parseScenarioKey, scenarioTitle, scenarioRowLabel,
  threeBettorGroupTitle, chartsForCategory, chartAction, actionsEqual,
  actionContains, handCombos, fractionContaining, gradeChart,
  pureComboCountFor, mixedComboCount, recallPaletteFor, unifiedRFI,
} from './domain.js';
import { CHART_FILES, loadAllCharts } from './charts.js';
import {
  loadPalette, savePalette, loadRFIPalette, saveRFIPalette,
  DEFAULT_PALETTE, DEFAULT_RFI_PALETTE,
  colorForAction, colorForChartAction, colorForRing,
  resolveAutoFoldColor, foregroundOn,
} from './colors.js';

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
  unified: null,
  palette: loadPalette(),
  rfiPalette: loadRFIPalette(),
  loadError: null,
  // Current view's redraw hook — set by renderers that need to redraw after
  // a palette change.
  onPaletteChange: null,
};

function setPaletteSlot(key, value) {
  state.palette = { ...state.palette, [key]: value };
  savePalette(state.palette);
  state.onPaletteChange?.();
}

function setRFIPaletteSlot(key, value) {
  state.rfiPalette = { ...state.rfiPalette, [key]: value };
  saveRFIPalette(state.rfiPalette);
  state.onPaletteChange?.();
}

function resetPalettes() {
  state.palette = { ...DEFAULT_PALETTE };
  state.rfiPalette = { ...DEFAULT_RFI_PALETTE };
  savePalette(state.palette);
  saveRFIPalette(state.rfiPalette);
  state.onPaletteChange?.();
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

function paintCell(cell, fill, fg, label) {
  cell.style.backgroundColor = fill;
  cell.style.color = fg;
  if (label != null) cell.firstChild.textContent = label;
}

// Drag-to-paint with Pointer Events. The grid uses `touch-action: none` so
// the page doesn't scroll or zoom during a gesture. On touch, pointer
// capture keeps the pointerdown target fixed, so we use
// document.elementFromPoint on move to find the cell under the finger.
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
    // Release implicit touch pointer capture so elementFromPoint sees the
    // real element under the finger on later moves.
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
  return h('div', { class: 'legend-item' }, [
    h('span', { class: 'swatch', style: `background-color: ${fill}` }),
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
    if (mc > 0 && mf === 0) mixLabel = '3-Bet/Call';
    else if (mf > 0 && mc === 0) mixLabel = '3-Bet/Fold';
    else if (mc > 0 && mf > 0) mixLabel = 'Mixed';
    items.push(legendItemEl(colorForAction(state.palette, '3bet'), '3-Bet', pFrac));
    if (mFrac > 0) items.push(legendItemEl(state.palette['3betCall'], mixLabel, mFrac));
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
    if (mFrac > 0) items.push(legendItemEl(state.palette['4betCall'], '4-Bet/Call', mFrac));
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
    if (mFrac > 0) items.push(legendItemEl(state.palette['5betCall'], 'All-In/Call', mFrac));
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

  clear(root);
  root.appendChild(page('GG 6-Max Cash Ranges', null, [list]));
}

function categoryRowContent(chart) {
  const scenario = chart.scenario;
  const pill = (color, text) => h('span', {
    class: 'count-pill',
    style: `background-color: ${color}; color: ${foregroundOn(color)}`,
  }, text);
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
        m > 0 && pill(state.palette['3betCall'], `${m} mix`),
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
        m > 0 && pill(state.palette['4betCall'], `${m} mix`),
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
        m > 0 && pill(state.palette['5betCall'], `${m} mix`),
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
      const fill = colorForChartAction(state.palette, ca);
      paintCell(cell, fill, foregroundOn(fill));
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

  const meta = [];
  if (chart.openSize) meta.push(h('div', { class: 'meta-line' }, `Open size: ${chart.openSize}`));
  if (chart.note) meta.push(h('div', { class: 'meta-line' }, chart.note));

  const back = scenario.kind === 'rfi' ? '#/rfi' : backHrefForScenario(scenario);
  const body = [
    h('div', { class: 'grid-wrap' }, [grid]),
    legend,
    meta.length ? h('div', { class: 'meta' }, meta) : null,
    h('div', { class: 'actions' }, [toggleBtn, practice]),
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

  function cellCA(hand) {
    const ring = unified.ringFor(hand);
    if (!ring) return null;
    return ring;
  }

  function repaint() {
    for (const cell of grid.children) {
      const hand = cell.dataset.hand;
      const ring = revealed ? cellCA(hand) : null;
      const fill = revealed
        ? colorForRing(state.rfiPalette, ring)
        : (state.rfiPalette.fold ?? resolveAutoFoldColor());
      paintCell(cell, fill, foregroundOn(fill));
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

  // Per-position RFI recall shortcuts (web-only addition — AC5.4)
  const practice = h('div', { class: 'practice-group' }, [
    h('div', { class: 'practice-label' }, 'Practice RFI by position:'),
    h('div', { class: 'practice-row' },
      ['UTG','MP','CO','BTN','SB']
        .filter(p => state.chartByKey.has(`rfi.${p.toLowerCase()}`))
        .map(p => h('a', {
          class: 'btn',
          href: `#/recall/rfi.${p.toLowerCase()}`,
        }, p))
    ),
  ]);

  const rfiColors = h('a', { class: 'btn', href: '#/rfi-colors/rfi' }, 'Edit RFI Colors');

  clear(root);
  root.appendChild(page('RFI', '#/', [
    h('div', { class: 'grid-wrap' }, [grid]),
    legend,
    h('div', { class: 'actions' }, [toggle, rfiColors]),
    practice,
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
      paintCell(cell, fill, fg);
      return;
    }
    const answer = painted.get(hand);
    if (answer) {
      const fill = colorForChartAction(state.palette, answer);
      paintCell(cell, fill, foregroundOn(fill));
    } else {
      const fill = foldColor();
      paintCell(cell, fill, foregroundOn(fill));
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
          style: `background-color: ${colorForChartAction(state.palette, o.answer)}`,
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
  // Spec AC6.5: correct non-fold = green, correct fold = gray, missed =
  // orange, wrong (both non-fold but differ) = yellow, extra = red.
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

function renderColorsPage(root) {
  const rows = h('div', { class: 'form' }, [
    sectionHeader('Pure actions'),
    colorRow('Fold',   'fold'),
    colorRow('Call',   'call'),
    colorRow('Open',   'open'),
    colorRow('3-Bet',  '3bet'),
    colorRow('4-Bet',  '4bet'),
    colorRow('All-In', '5bet'),
    sectionHeader('Mixed actions'),
    colorRow('3-Bet / Call', '3betCall'),
    colorRow('3-Bet / Fold', '3betFold'),
    colorRow('4-Bet / Call', '4betCall'),
    colorRow('All-In / Call', '5betCall'),
    h('div', { class: 'actions' }, [
      h('a', { class: 'btn', href: '#/rfi-colors' }, 'Edit RFI Colors →'),
    ]),
    h('div', { class: 'actions' }, [
      (() => {
        const b = h('button', { class: 'btn btn-destructive' }, 'Reset to defaults');
        b.addEventListener('click', () => { resetPalettes(); renderColorsPage(root); });
        return b;
      })(),
    ]),
  ]);
  clear(root);
  root.appendChild(page('Colors', '#/', [rows]));
}

function colorRow(label, key) {
  const current = state.palette[key] ?? resolveAutoFoldColor();
  const picker = h('input', { type: 'color', value: current });
  picker.addEventListener('input', () => setPaletteSlot(key, picker.value));
  const row = h('div', { class: 'form-row' }, [
    h('span', { class: 'form-label' }, label),
    picker,
    key === 'fold' ? (() => {
      const btn = h('button', { class: 'btn btn-small' }, 'Auto');
      btn.addEventListener('click', () => {
        setPaletteSlot('fold', null);
        picker.value = resolveAutoFoldColor();
      });
      return btn;
    })() : null,
  ].filter(Boolean));
  return row;
}

function rfiColorRow(label, key) {
  const current = state.rfiPalette[key] ?? resolveAutoFoldColor();
  const picker = h('input', { type: 'color', value: current });
  picker.addEventListener('input', () => setRFIPaletteSlot(key, picker.value));
  return h('div', { class: 'form-row' }, [
    h('span', { class: 'form-label' }, label),
    picker,
  ]);
}

function sectionHeader(label) {
  return h('div', { class: 'section-header' }, label);
}

// Reachable from the unified RFI page (`#/rfi-colors/rfi`) and from the
// Colors page (`#/rfi-colors`); Back returns to whichever one opened it.
function renderRFIColorsPage(root, from) {
  const backHref = from === 'rfi' ? '#/rfi' : '#/colors';
  const rows = h('div', { class: 'form' }, [
    sectionHeader('RFI ring colors'),
    rfiColorRow('UTG',    'utg'),
    rfiColorRow('MP',     'mp'),
    rfiColorRow('CO',     'co'),
    rfiColorRow('BTN/SB', 'btnSb'),
    rfiColorRow('Fold',   'fold'),
    h('div', { class: 'actions' }, [
      (() => {
        const b = h('button', { class: 'btn btn-destructive' }, 'Reset to defaults');
        b.addEventListener('click', () => {
          state.rfiPalette = { ...DEFAULT_RFI_PALETTE };
          saveRFIPalette(state.rfiPalette);
          renderRFIColorsPage(root, from);
        });
        return b;
      })(),
    ]),
  ]);
  clear(root);
  root.appendChild(page('Edit RFI Colors', backHref, [rows]));
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
    default:            return { name: 'home' };
  }
}

function route(root) {
  state.onPaletteChange = null;
  const r = parseHash();
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
    default: renderHome(root);
  }
}

// ------------------- Boot -------------------

async function boot() {
  const root = document.getElementById('app');
  // Loading indicator
  clear(root);
  root.appendChild(h('div', { class: 'loading' }, 'Loading charts…'));

  try {
    state.allCharts = await loadAllCharts();
    state.chartByKey = new Map(state.allCharts.map(c => [c.scenario.key, c]));
    state.unified = unifiedRFI(state.allCharts);
  } catch (err) {
    state.loadError = err;
  }

  route(root);
  window.addEventListener('hashchange', () => route(root));

  // Dark-mode auto fold color: when the system scheme flips and no explicit
  // override exists, repaint the active view in place. Re-routing would
  // destroy an in-progress recall grid, so we call the view's palette
  // hook if it set one.
  const mql = matchMedia?.('(prefers-color-scheme: dark)');
  mql?.addEventListener?.('change', () => state.onPaletteChange?.());

  // Register service worker (relative URL so it works on GitHub Pages).
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    try { await navigator.serviceWorker.register('./sw.js'); }
    catch (err) { console.warn('SW registration failed:', err); }
  }
}

boot();
