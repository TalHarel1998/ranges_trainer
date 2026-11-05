# PreflopT Web — Feature Spec

Web (PWA) port of the iOS PreflopT app, installable on iPhone via Safari
"Add to Home Screen". This file is the contract between the coder and the
reviewer. Every acceptance criterion (AC) must be verifiable.

Reference implementation: the Swift sources under `PreflopT/PreflopT/`.
When this spec is silent, match the Swift behavior.

## Constraints

- Plain HTML + CSS + JavaScript (ES modules). No npm dependencies, no build step,
  no frameworks, no CDNs, no external network requests (fonts, analytics, etc.).
- All files live under `web/`. The iOS app (`PreflopT/`) MUST NOT be modified.
- Chart data is NOT copied. `web/charts` is a git symlink to
  `../PreflopT/PreflopT/Resources/Charts`. The list of chart files is hardcoded
  in `web/js/charts.js` (browsers cannot list directories).
- All URLs relative (site is served from `/ranges_trainer/` on GitHub Pages).
- Hash-based routing (`#/...`) so no server config is needed.
- Domain logic (`web/js/domain.js`) is pure: no DOM access, importable from Node.
- Tests: `node --test web/tests/*.test.mjs` using only `node:test` + `node:assert`.
- Local dev server binds to loopback only:
  `python3 -m http.server 8000 --bind 127.0.0.1 --directory web`.
- No chart editing feature. Charts change only by editing JSON in git.

## Domain model (port of Swift `Domain/`)

- Ranks `2..A`, symbols `23456789TJQKA`.
- HandClass: 169 classes. Symbol `AA` (pair), `AKs` (suited), `AKo` (offsuit).
  Combos: pair 6, suited 4, offsuit 12 (sum 1326).
- Grid (13×13): row/col 0 = A ... 12 = 2. Diagonal = pairs. `col > row` =
  suited (row rank high). `row > col` = offsuit (col rank high). E.g. (0,1)=AKs,
  (1,0)=AKo.
- Range string parser (case-insensitive, whitespace tolerant, empty string = empty set):
  `AA`, `AKs`, `AKo`, `22+` (22..AA), `A2s+` (A2s..AKs), `K9o+` (K9o..KQo).
  Invalid token → throws.
- Actions: fold, call, open, 3bet, 4bet, 5bet.
- ChartAction: `pure(action)` or `mixed(aggressive, passive)`.
- Chart JSON → entries (missing hand = pure fold):
  - `rfi`: `range` → pure open. `openSize`, `note` optional.
  - `defense`: `threeBet` → pure 3bet; `mixed3betCall` → mixed(3bet, call);
    `mixed3betFold` → mixed(3bet, fold); `call` → pure call.
  - `vs3bet`: `fourBet` → pure 4bet; `mixed4betCall` → mixed(4bet, call); `call`.
  - `vs4bet`: `fiveBet` → pure 5bet; `mixed5betCall` → mixed(5bet, call); `call`.
  - Same hand in two fields of one chart → throws (names the hand + fields).
  - Unknown chartType or bad scenario key → throws.
- Scenario keys: `rfi.<hero>`, `def.<hero>.vs.<villain>`,
  `vs3b.<hero>.vs.<ip|oop>`, `vs4b.<hero>.vs.<villain>`.
  Positions in action order: UTG, MP, CO, BTN, SB, BB.
- 3-bettor groups (`Scenario.threeBettors`): candidates act after hero preflop.
  Post-flop order SB(0) BB(1) UTG(2) MP(3) CO(4) BTN(5). `ip` = post-flop order
  greater than hero's; `oop` = smaller. Title: one villain → `vs BB`,
  several → `vs <first>-<last>` (e.g. UTG ip → `vs MP-BTN`, UTG oop → `vs SB-BB`).
- Combo counting for legends/rows: mixed cells count their full combo count
  in the "mix" bucket (as Swift `ChartDetailView` / row views do).
- Unified RFI: ring per hand = earliest of UTG, MP, CO, BTN that opens it
  (BTN/SB share a ring). Cumulative % for position P = P's open combos / 1326.

## Features and acceptance criteria

### F1 — Chart loading
- AC1.1 All 23 chart files listed in `charts.js` load and parse with no error.
- AC1.2 Parser handles every token form above; invalid tokens throw.
- AC1.3 Overlap between fields of one chart throws.
- AC1.4 Cross-check against iOS tests: `def.bb.vs.utg` has 9 pure 3-bet, 11 mixed,
  51 pure call hand classes (71 non-fold); AA/AKs = pure 3bet, JJ/A7s = mixed(3bet,call),
  TT/A8s = pure call, 72o = fold. `def.bb.vs.co` has 16 pure 3-bet, 10 mixed.
  Unified RFI: AA, KK in UTG ring; every UTG-open hand in UTG ring; 72o unassigned;
  cumulative fractions strictly increase UTG < MP < CO < BTN < 1.
- AC1.5 If a chart fails to load, the app shows an error message naming the file
  instead of a blank screen.

### F2 — Home
- AC2.1 Title "GG 6-Max Cash Ranges".
- AC2.2 Categories in order: RFI, BTN defense, SB defense, BB defense,
  UTG vs 3-Bet, CO vs 3-Bet, BTN vs 3-Bet, SB vs 3-Bet, BTN vs 4-Bet, SB vs 4-Bet.
  Categories with zero charts are hidden.
- AC2.3 RFI subtitle "Unified — all positions"; others "N chart(s)".
- AC2.4 A "Colors" entry links to settings (F7).

### F3 — Category list
- AC3.1 Defense sorted by villain action order; vs 3-bet: ip before oop;
  vs 4-bet by villain action order.
- AC3.2 Row label: defense `vs <villain>`; vs 3-bet group title (`vs MP-BTN`);
  vs 4-bet `vs <villain>`.
- AC3.3 Row shows non-zero combo counts: defense `N 3-bet` / `N mix` / `N call`;
  vs 3-bet `N 4-bet` / `N mix` / `N call`; vs 4-bet `N all-in` / `N mix` / `N call`.
  Each count is tinted with its action color.
- AC3.4 Tapping a row opens F4. A back control returns to Home.

### F4 — Chart view (read-only)
- AC4.1 Title: `UTG RFI`, `BB vs BTN`, `UTG vs MP-BTN`, `BTN vs CO 4-Bet`.
- AC4.2 13×13 grid. Hidden by default (all cells fold-gray with hand labels).
  "Show"/"Hide" button toggles the colors.
- AC4.3 Legend (always visible) with color swatch, label, percent of 1326 combos
  (1 decimal):
  RFI: Open, Fold. Defense: 3-Bet, mix (label `3-Bet/Call`, `3-Bet/Fold`, or
  `Mixed` if both kinds), Call (only if >0), Fold. vs 3-bet: 4-Bet, 4-Bet/Call (if >0),
  Call (if >0), Fold. vs 4-bet: All-In, All-In/Call (if >0), Call (if >0), Fold.
- AC4.4 "Practice: Chart Recall" button opens F6 for this chart.
- AC4.5 No Edit button anywhere in the app.
- AC4.6 If the chart has `openSize` or `note`, it is shown as small text.

### F5 — Unified RFI
- AC5.1 Opening "RFI" from Home shows one grid colored by ring
  (default UTG red, MP orange, CO yellow, BTN/SB green, fold gray).
- AC5.2 Revealed by default; Show/Hide toggle.
- AC5.3 Legend: UTG, MP, CO, BTN/SB with cumulative percent.
- AC5.4 Links to each per-position RFI chart (UTG/MP/CO/BTN/SB) so Chart Recall
  can be practiced for each position. (Web addition; iOS lacks this entry point.)

### F6 — Chart Recall
- AC6.1 Prompt: RFI "Tap the hands you would open."; others
  "Tap cells with the action you would take."
- AC6.2 Paint palette derived from the chart's actual actions, in order:
  Open, All-In, 4-Bet, 3-Bet, All-In/Call, 4-Bet/Call, 3-Bet/Call, 3-Bet/Fold, Call.
  First option selected by default; selected option visibly highlighted.
  Painted-cell count shown.
- AC6.3 Tap paints a cell with the selected option. Drag (touch or mouse)
  paints every cell crossed, each once per gesture. If the gesture starts on a cell
  already painted with the selected option, the gesture erases (back to fold)
  instead. The page must not scroll or zoom while dragging on the recall grid.
  Read-only grids (chart view, unified RFI) must NOT block page scrolling.
- AC6.4 Clear empties the grid. Submit is disabled while nothing is painted.
- AC6.5 Grading per cell (port of `ChartRecallGrading.gradeOne`): exact match =
  correct; user fold vs chart non-fold = missed; user non-fold vs chart fold = extra;
  both non-fold but different (incl. pure vs mixed) = wrong.
  Colors: correct non-fold = green, correct fold = gray, missed = orange,
  wrong = yellow, extra = red.
- AC6.6 Graded header shows counts `N missed`, `N wrong`, `N extra` (only non-zero),
  or `Perfect` if all zero. Grid not paintable when graded.
- AC6.7 "Try again" returns to an empty painting grid.

### F7 — Colors
- AC7.1 Edit colors for: call, open, 3-bet, 4-bet, all-in, 3-bet/call, 3-bet/fold,
  4-bet/call, all-in/call; and RFI rings UTG, MP, CO, BTN/SB.
  Defaults match Swift `ColorPalette.default` / `RFIColorPalette.default`.
- AC7.2 Changes apply immediately everywhere and persist across reloads
  (localStorage). "Reset to defaults" restores them.
- AC7.3 Cell text color auto-contrasts (BT.601 luminance > 0.6 → dark text, else white).

### F8 — Installable app (PWA)
- AC8.1 `manifest.webmanifest`: name "PreflopT", short_name "PreflopT",
  `display: standalone`, relative `start_url` and `scope`, theme/background colors,
  icons 192 and 512 PNG. `apple-touch-icon` 180×180 PNG linked from index.html.
- AC8.2 iOS meta: `apple-mobile-web-app-capable`, `apple-mobile-web-app-title`,
  status bar style; viewport with `viewport-fit=cover`; layout respects
  `env(safe-area-inset-*)`.
- AC8.3 Service worker precaches the app shell, all 23 charts and icons.
  Navigations and `.js`/`.css`/`.webmanifest`/`.json` are network-first with a ~3s
  timeout and cache fallback (so a deploy is visible on the next launch); icons are
  cache-first. After one online visit, the app fully works offline. Cache name is
  `preflopt-<short SHA>` (the workflow replaces `__BUILD__`); old caches are deleted on activate.
- AC8.4 Light and dark mode via `prefers-color-scheme`.
- AC8.5 Grid fits a 375px-wide screen without horizontal scrolling; cells are
  square; tap targets usable on iPhone.

### F9 — Publishing
- AC9.1 `.github/workflows/pages.yml`: on push to `main` (and manual dispatch),
  copy `web/` into `_site` with symlinks dereferenced (`cp -RL`), run the Node tests,
  then deploy with `actions/upload-pages-artifact` + `actions/deploy-pages`.
  Minimal permissions: `contents: read`, `pages: write`, `id-token: write`.
- AC9.2 `SPEC.md` and `tests/` are not required in `_site` (may be excluded).

## Out of scope

Chart editing, Situation Drill, stats/progress tracking, sync between devices.
