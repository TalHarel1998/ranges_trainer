// Hardcoded list of the 23 chart file paths plus a browser loader.
//
// Browsers can't list directories, so we ship the file list. Paths are all
// relative to the HTML page and resolve through the `charts` symlink
// (web/charts → ../PreflopT/PreflopT/Resources/Charts).

import { buildChart } from './domain.js';

export const CHART_FILES = Object.freeze([
  // RFI (5)
  'charts/rfi/utg.json',
  'charts/rfi/mp.json',
  'charts/rfi/co.json',
  'charts/rfi/btn.json',
  'charts/rfi/sb.json',

  // Defense (8)
  'charts/defense/btn_vs_utg.json',
  'charts/defense/btn_vs_co.json',
  'charts/defense/sb_vs_utg.json',
  'charts/defense/sb_vs_co.json',
  'charts/defense/sb_vs_btn.json',
  'charts/defense/bb_vs_utg.json',
  'charts/defense/bb_vs_co.json',
  'charts/defense/bb_vs_btn.json',

  // vs 3-Bet (6)
  'charts/vs_3bet/utg_vs_ip.json',
  'charts/vs_3bet/utg_vs_oop.json',
  'charts/vs_3bet/co_vs_ip.json',
  'charts/vs_3bet/co_vs_oop.json',
  'charts/vs_3bet/btn_vs_oop.json',
  'charts/vs_3bet/sb_vs_ip.json',

  // vs 4-Bet (4)
  'charts/vs_4bet/vs4b_btn_vs_utg.json',
  'charts/vs_4bet/vs4b_btn_vs_co.json',
  'charts/vs_4bet/vs4b_sb_vs_co.json',
  'charts/vs_4bet/vs4b_sb_vs_btn.json',
]);

export class ChartLoadError extends Error {
  constructor(file, cause) {
    super(`Failed to load chart '${file}': ${cause?.message ?? cause}`);
    this.name = 'ChartLoadError';
    this.file = file;
    this.cause = cause;
  }
}

// Fetch the raw text for a single chart path. Does NOT parse.
export async function fetchChartText(path) {
  const res = await fetch(path, { cache: 'default' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.text();
}

// Parse a chart file's text into a domain chart. Wraps errors so the caller
// knows which file failed.
export function parseChartText(path, text) {
  try {
    return buildChart(JSON.parse(text));
  } catch (err) {
    throw new ChartLoadError(path, err);
  }
}

// Fetch raw text for every chart file in parallel. Returns a map
// { path: text } for every file that fetched successfully, and throws a
// ChartLoadError on the first failure.
export async function fetchAllChartTexts() {
  const results = await Promise.allSettled(CHART_FILES.map(fetchChartText));
  const texts = {};
  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    if (r.status === 'fulfilled') {
      texts[CHART_FILES[i]] = r.value;
    } else {
      throw new ChartLoadError(CHART_FILES[i], r.reason);
    }
  }
  return texts;
}

// Build every chart from a prefetched text map. Any parse error is wrapped
// in a ChartLoadError naming the file (AC1.5).
export function buildAllCharts(texts) {
  const charts = [];
  for (const path of CHART_FILES) {
    const text = texts[path];
    if (typeof text !== 'string') {
      throw new ChartLoadError(path, new Error('No text provided'));
    }
    charts.push(parseChartText(path, text));
  }
  return charts;
}

// Convenience: fetch and parse in one go. Preserves prior API.
export async function loadAllCharts() {
  const texts = await fetchAllChartTexts();
  return buildAllCharts(texts);
}
