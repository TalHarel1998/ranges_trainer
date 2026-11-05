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

async function fetchChart(path) {
  const res = await fetch(path, { cache: 'default' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const dto = await res.json();
  return buildChart(dto);
}

export async function loadChart(path) {
  try {
    return await fetchChart(path);
  } catch (err) {
    throw new ChartLoadError(path, err);
  }
}

// Load every chart in parallel. On the first failure, surfaces a
// ChartLoadError that names the failing file (per AC1.5).
export async function loadAllCharts() {
  const results = await Promise.allSettled(CHART_FILES.map(fetchChart));
  const charts = [];
  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    if (r.status === 'fulfilled') {
      charts.push(r.value);
    } else {
      throw new ChartLoadError(CHART_FILES[i], r.reason);
    }
  }
  return charts;
}
