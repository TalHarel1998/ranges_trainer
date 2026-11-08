// F18: the frozen GTO snapshot (web/gto/) must cover every chart and parse.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { buildChart } from '../js/domain.js';
import { CHART_FILES } from '../js/charts.js';
import { gtoPathFor } from '../js/config.js';

const WEB = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const load = async (p) => buildChart(JSON.parse(await readFile(path.join(WEB, p), 'utf8')));

test('gtoPathFor maps charts/ to gto/', () => {
  assert.equal(gtoPathFor('charts/defense/bb_vs_btn.json'), 'gto/defense/bb_vs_btn.json');
  assert.throws(() => gtoPathFor('palette.json'));
});

test('every chart has a GTO snapshot that parses with the same scenario', async () => {
  for (const f of CHART_FILES) {
    const [live, gto] = await Promise.all([load(f), load(gtoPathFor(f))]);
    assert.equal(gto.scenario.key, live.scenario.key, f);
  }
});

test('sw.js precaches the GTO files', async () => {
  const sw = await readFile(path.join(WEB, 'sw.js'), 'utf8');
  assert.match(sw, /GTO_FILES/);
  assert.match(sw, /\.\.\.GTO_FILES/);
});
