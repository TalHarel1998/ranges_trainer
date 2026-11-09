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
- Charts and colors are edited either in git (Mac) or in the app, which commits to
  GitHub via the REST API (F10–F13). The repo on GitHub is the single source of
  truth; nothing edited in the app lives only on the device (except the token).
- The only external origin the app may contact is `https://api.github.com`, and only
  when a token is configured.

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
- AC4.5 Edit button appears only when a GitHub token is configured (F10); see F11.
- AC4.6 If the chart has `openSize` or `note`, it is shown as small text.

### F5 — Unified RFI
- AC5.1 Opening "RFI" from Home shows one grid colored by ring
  (default UTG red, MP orange, CO yellow, BTN/SB green, fold gray).
- AC5.2 Revealed by default; Show/Hide toggle.
- AC5.3 Legend: UTG, MP, CO, BTN/SB with cumulative percent.
- AC5.4 Row of position buttons (UTG/MP/CO/BTN/SB) linking to each per-position RFI
  chart view (`#/chart/rfi.<pos>`), which has Practice (and Edit, F11). (Updated:
  previously linked straight to recall.)

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
- AC7.2 (Superseded by F12.) Colors come from `web/palette.json` in the repo, not
  localStorage. Picker changes preview immediately everywhere; they persist only
  when saved to GitHub (F12). "Reset to defaults" sets the built-in defaults as the
  unsaved preview.
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

Situation Drill, stats/progress tracking, multi-user accounts, editing from the iOS
app to GitHub, OAuth login (token is pasted manually).

## Editing via GitHub (F10–F14)

Repo constants live in one module (`web/js/config.js`): owner `TalHarel1998`, repo
`ranges_trainer`, branch `main`, chart repo dir
`PreflopT/PreflopT/Resources/Charts/` (maps from app path `charts/<x>`), palette
path `web/palette.json`.

### F10 — GitHub connection (Settings)
- AC10.1 Home has a "GitHub" row → `#/github`. The page explains in one sentence
  what the token does, and how to create one: fine-grained token, only repo
  `ranges_trainer`, Repository permission Contents: Read and write, nothing else.
- AC10.2 Token input is `type=password`, `autocomplete=off`, no autocapitalize /
  autocorrect / spellcheck. "Save & test" calls
  `GET https://api.github.com/repos/TalHarel1998/ranges_trainer` with
  `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`,
  `X-GitHub-Api-Version: 2022-11-28`. That check requires HTTP 200 and
  `permissions.push === true`, but GitHub reports the *account's* permissions
  there, not the token's. So Save & test also runs a write probe:
  GET `web/palette.json`, then PUT the identical content with sha
  `0000000000000000000000000000000000000000`. 409/422 = the token can write
  (nothing is written); 403/404 = read-only token → message telling the user to
  set Repository permissions → Contents: Read and write. Only after both pass is
  the token stored in localStorage key
  `preflopt.githubToken.v1` and the page shows "Connected — can write to
  ranges_trainer". Failure (401/403/404/no push permission/no write/network) shows a clear
  message and does NOT store the token.
- AC10.3 "Remove token" deletes it from localStorage and hides all edit/save UI.
- AC10.4 The token never appears in: the DOM after saving (input cleared, masked
  as "•••• last 4"), URLs, console output, error messages, the service-worker cache,
  or any request other than to `https://api.github.com`.
- AC10.5 The service worker must not intercept or cache any cross-origin request
  (api.github.com requests go straight to the network).

### F11 — Chart editor
- AC11.1 Chart view (F4) shows an "Edit" button only when a token is stored.
  Route `#/edit/<scenarioKey>`. Without a token, the route shows a message linking
  to `#/github`.
- AC11.2 On open, the editor fetches the file from the GitHub contents API
  (`GET /repos/{o}/{r}/contents/{path}?ref=main`) to get its `sha` and current
  content. If that content's chart differs from the one the app loaded (deploy
  lag), the editor uses the GitHub version as the starting point and shows a note
  "Loaded the latest version from GitHub."
- AC11.3 Grid starts revealed with the chart's colors. Paint palette = every action
  valid for the chart type (not only those present), plus "Fold" (eraser):
  rfi: Open, Fold. defense: 3-Bet, 3-Bet/Call, 3-Bet/Fold, Call, Fold.
  vs3bet: 4-Bet, 4-Bet/Call, Call, Fold. vs4bet: All-In, All-In/Call, Call, Fold.
  Tap/drag paint works like F6 (same gesture code, same erase-on-start rule:
  starting on a cell already set to the selected option sets the gesture to Fold).
- AC11.4 Cells that differ from the starting chart show a small marker dot.
  A counter shows the number of changed hands. "Revert" restores the start state.
  "Save" is disabled when nothing changed.
- AC11.5 Save shows a confirmation listing changes grouped by action, e.g.
  "Open: +A9o, +K8s · Fold: +T7s", plus Cancel / Commit buttons.
- AC11.6 Commit: build the new JSON (F13), validate it with `buildChart` (must not
  throw), then `PUT /repos/{o}/{r}/contents/{path}` with
  `{ message: "Edit <chart title> from web app", content: <base64 UTF-8>,
  sha: <sha from AC11.2>, branch: "main" }`. On success: in-memory chart updated
  immediately (chart view, recall, unified RFI, category counts all reflect it),
  toast "Saved to GitHub — live on other devices in about a minute", navigate back
  to the chart view.
- AC11.7 On 409 or 422 (sha mismatch): message "This chart changed on GitHub since
  you opened it. Reload the editor and re-apply your edit." Nothing overwritten;
  edits stay on screen. On 401: "Token rejected (expired, revoked or mistyped) —
  check it in GitHub settings." On 403: "Token can’t write to ranges_trainer. On
  GitHub, edit the token: Repository permissions → Contents: Read and write. Then
  check it in GitHub settings." Both inline, with a link to `#/github`.
  On network error: "Couldn't reach GitHub", edits kept.
  Save button shows a busy state and is not double-submittable.
- AC11.8 Leaving the editor with unsaved changes (Back link or hash change) asks
  for confirmation (`confirm()`); declining keeps the user on the editor.

### F12 — Colors saved to the repo
- AC12.1 `web/palette.json` holds both palettes:
  `{ "actions": { "fold": null, "call": "#38B359", ... }, "rfi": { "utg": ..., "fold": null } }`
  with the same keys/defaults as `colors.js`. `null` fold = automatic light/dark gray.
  It is loaded at boot (same loader path as charts, precached by the SW). If missing
  or invalid, built-in defaults are used and the app still works.
- AC12.2 Old localStorage palettes (`preflopt.palette.v1`, `preflopt.rfiPalette.v1`)
  are ignored and deleted on boot.
- AC12.3 Colors pages: with no token, pickers are disabled and a note says
  "Colors come from the repo. Add a GitHub token to change them." With a token,
  pickers preview live; a "Save colors to GitHub" button (disabled until something
  changed) commits `web/palette.json` (fetch sha first, same PUT/conflict/error
  handling as AC11.6–11.7, message "Update colors from web app"). Leaving with
  unsaved color changes reverts the preview to the saved palette (no prompt needed).
- AC12.4 Both the Colors page and the RFI Colors page can save; each saves the whole
  palette file.

### F13 — JSON writing (pure, in domain.js or a new pure module)
- AC13.1 `serializeRange(set)` produces a compact canonical range string: pairs from
  high to low, using `XX+` for a run that reaches AA and single tokens otherwise; then
  suited hands grouped by high rank (A..3), using `HLs+` when the run of low ranks
  reaches high−1 and single tokens otherwise; then offsuit the same way. Tokens joined
  by ", ". `parseRange(serializeRange(s))` equals `s` for every subset tested,
  including all 23 charts' fields and randomized sets.
- AC13.2 `chartToFileJSON(originalText, editedEntries)` returns the new file text:
  starts from the original parsed object (key order preserved); for each action
  field of the chart type, if its hand set changed, replace the string with
  `serializeRange`; unchanged fields keep their original string byte-for-byte; a
  field that becomes non-empty but did not exist is added after the existing range
  fields; a field that becomes empty is kept as `""` (rfi `range` may be `""`).
  Output is `JSON.stringify(obj, null, 2) + "\n"`.
- AC13.3 With no edits, output equals the original file text byte-for-byte for all
  23 charts (test). Output always passes `buildChart`.
- AC13.4 Base64 encoding handles UTF-8 (e.g. a `note` containing "—" or "♠").

### F14 — Showing saved edits before the deploy finishes
- AC14.1 After a successful commit, store `{ path, text, savedAt }` in localStorage
  (`preflopt.pendingWrites.v1`). On boot, for each pending write: if the deployed file
  equals `text`, delete it; else if `savedAt` is under 30 minutes old, use `text`
  instead of the deployed file; else delete it. Applies to charts and palette.json.
- AC14.2 This prevents a just-saved edit from appearing to "revert" when the app is
  reopened before GitHub Pages redeploys.

### F15 — Security hardening
- AC15.1 `index.html` has a Content-Security-Policy meta tag:
  `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';
  img-src 'self' data:; connect-src 'self' https://api.github.com;
  manifest-src 'self'; worker-src 'self'; object-src 'none'; base-uri 'self';
  form-action 'none'`. The app works fully under it (no inline scripts).
- AC15.2 All user/remote text is inserted with `textContent` / text nodes, never
  `innerHTML` (chart notes, error messages from GitHub, etc.).

### F16 — No double-tap zoom
- AC16.1 A quick double tap anywhere in the app (buttons such as Show/Hide, links,
  rows, grids) never zooms the page on iPhone Safari / home-screen app. Each tap is
  delivered as a normal tap. Implemented with CSS `touch-action: manipulation` on
  `html`, `body` and all interactive elements (`a`, `button`, `.btn`, `.row`,
  `input`, `.palette-btn`, read-only `.grid`); `.grid.interactive` keeps
  `touch-action: none`.
- AC16.2 Pinch-to-zoom stays possible (accessibility): the viewport meta must NOT
  add `maximum-scale` or `user-scalable=no`.

### F17 — Split cells for mixed actions
- AC17.1 Every grid cell whose action is `mixed(aggressive, passive)` is drawn
  split vertically: left half = the aggressive action's pure color, right half = the
  passive action's pure color (call → call color, fold → fold color, incl. the
  automatic light/dark fold gray). E.g. 3-Bet/Call = left 3-bet red, right call
  green; 3-Bet/Fold = left red, right fold gray. Hard edge at exactly 50%
  (`linear-gradient(to right, L 50%, R 50%)`).
- AC17.2 Applies in: chart view (revealed), chart editor (start state and painted
  cells), Chart Recall while painting. Recall graded cells (green/orange/yellow/red)
  stay solid. Unified RFI has no mixed cells.
- AC17.3 The same split is used for swatches of mixed options: chart legend "mix"
  item, recall and editor paint-option buttons, and the "N mix" count pill in
  category rows.
- AC17.4 Cell label legibility: if both halves call for the same text color
  (AC7.3 rule), use it; otherwise use white text with a dark outline
  (`text-shadow`) so it reads on both halves.
- AC17.5 Mixed colors are no longer drawn anywhere, so the four mixed pickers
  (3-Bet/Call, 3-Bet/Fold, 4-Bet/Call, All-In/Call) are removed from the Colors page.
  Their keys stay in `web/palette.json` unchanged (the file format is not changed;
  saving colors keeps those values as they are).
- AC17.6 Changing a pure color (e.g. call) immediately updates the matching half of
  every mixed cell and swatch.

### F16 revision — double-tap guard
- AC16.3 `touch-action: manipulation` alone did not stop double-tap zoom on the
  owner's iPhone. A document `touchend` listener now cancels the default of a
  single-finger tap that ends within 350 ms of the previous one, and delivers the
  click itself (`button`, `a`, `input`, `label`, `.palette-btn`). Fast taps on
  Show/Hide toggle twice. Painting on `.grid.interactive` is pointer-driven and is
  unaffected. Pinch zoom (multi-touch) is unaffected.

### F18 — Frozen GTO snapshot and "Restore to GTO"
- AC18.1 `web/gto/<group>/<file>.json` is a frozen copy of every chart, taken on
  2026-11-08 from `main` (after commit 214247c). The app never writes these
  files; they change only by a deliberate commit.
- AC18.2 The chart editor has a "Restore to GTO" button. It loads the snapshot
  for that chart into the grid as an unsaved edit: changed cells get the marker,
  the counter updates, and nothing is written until Save → Commit. A toast says
  how many cells changed ("Already matches GTO." when none).
- AC18.3 If the grid at commit time equals the snapshot exactly, the committed
  file text is the snapshot file byte for byte.
- AC18.4 The service worker precaches the 23 GTO files, so Restore works offline
  (the commit itself needs a connection).

### F19 — BB vs SB flop c-bet raise drill

Practice the simplified BB raising strategy vs an SB c-bet on the flop.

**Dealing**
- AC19.1 Hero hand: 2 cards drawn uniformly from the 52-card deck, redrawn until
  the hand class is one the BB continues with in chart `def.bb.vs.sb`
  (pure `call` or any mixed action; never pure `3bet`, never fold). This weights
  hands by combos, like real dealing.
- AC19.2 Flop: 3 cards drawn uniformly from the remaining 50. All 5 cards distinct.
- AC19.3 The dealing function takes an injectable random source so tests are
  deterministic.

**Hand evaluation** (pure module `web/js/postflop.js`, Node-testable). Let
H = hero's 2 cards, B = 3 board cards, ranks 2..A with A also low for straights.
- AC19.4 *Hero pair*: H is a pocket pair, or a hole card's rank appears on B.
  A pair made only by the board does not count.
- AC19.5 *Two pair or better* (hero-made, any of):
  set/trips — some rank appears ≥3 times in H∪B including at least one hole card
  (covers sets, trips, full houses, quads); two pair — the two hole cards have
  different ranks and both ranks are on B; straight — a 5-rank window (A2345 …
  TJQKA) fully covered by H∪B ranks with hero contribution (below); flush — 5
  cards of one suit. A paired board plus one hero pair (e.g. 77 on K♠K♦6♣) is
  one pair, not two pair.
- AC19.6 *Hero contribution* to a straight window W: W contains a rank held by a
  hole card that is not on B. (Straights that need no hole card don't count.)
- AC19.7 *Frontdoor straight draw*: no made straight, and some window W misses
  exactly 1 rank of H∪B ranks, with hero contribution. Includes gutshots.
- AC19.8 *Backdoor straight draw*: no made straight, and some window W misses
  exactly 2 ranks of H∪B ranks, with hero contribution. (Evaluated independently
  of frontdoor.)
- AC19.9 *Frontdoor flush draw*: some suit has exactly 4 cards in H∪B, at least
  one of them a hole card. *Backdoor flush draw*: some suit has exactly 3 cards in
  H∪B, at least one a hole card.
- AC19.10 *Correct answer*:
  1. Two pair or better → **Raise** ("Two pair or better — always raise").
  2. Exactly one hero pair and no draw of any kind (no frontdoor or backdoor
     flush/straight) → **Raise** ("Pair with no draws — hates a turn barrel").
  3. One hero pair with any draw → **Don't raise** ("Pair with a draw — call").
  4. No hero pair, backdoor flush AND backdoor straight, no frontdoor draw →
     **Raise** ("Double backdoor bluff").
  5. Otherwise → **Don't raise** ("No pair with a frontdoor draw — just call" or
     "No pair, not a double backdoor — just call").
- AC19.11 The evaluator returns `{ answer: 'raise'|'noRaise', rule: 1..5,
  made: 'twoPairPlus'|'pair'|'noPair', draws: { fdFlush, fdStraight, bdFlush,
  bdStraight } }` so the UI can explain it.
- AC19.12 Reference cases (all must be unit tests), board K♦Q♦6♣:
  K♠7♠ raise (1 pair, no draws); A♠K♣ no raise (pair + bd straight);
  6♥5♥ raise (pair, no draws: 5-6 plus K-Q is not 3 cards of any straight,
  and only 2 hearts); 9♣8♣ raise (bd flush + bd straight);
  J♥T♥ no raise (OESD); A♦5♦ no raise (fd flush); 2♠2♥ raise (pair, no draws);
  K♣Q♠ raise (two pair); 6♠6♥ raise (set). Plus: A♥5♣ on K♠K♣6♦ = no pair;
  7♠7♥ on K♠K♦6♣ = one pair; board 9♠8♦7♣ with A♥2♥: the T/J backdoor straight
  (needs no hole card) must NOT count; A♠2♠ on 4♦5♣K♥ = frontdoor (wheel gutshot);
  flush made with two suited hole cards on a monotone flop = two pair or better.

**UI**
- AC19.13 Home has a row "BB vs SB c-bet drill" → `#/drill/bb-vs-sb`. Shown only
  when chart `def.bb.vs.sb` is loaded.
- AC19.14 The drill shows: "BB vs SB · SB c-bets" heading, hero's 2 cards and the
  3 flop cards as card faces (rank + suit symbol; ♥♦ red, ♠♣ black, readable in
  dark mode), the question "Raise?", and two large buttons **Raise** /
  **Don't raise**.
- AC19.15 After answering: the result (Correct / Wrong) with the right answer and
  the reason text from AC19.10, plus what the hand has (e.g. "Pair · backdoor
  straight"), and a **Next hand** button. Answer buttons are disabled until Next;
  the button the user picked stays highlighted (class `picked`).
- AC19.16 Session score "Correct N / M" and current streak, in memory only (reset
  when leaving the page). Works offline (no network needed).
- AC19.17 Fast taps on Raise / Don't raise / Next must not zoom (F16 guard) and
  must not double-answer.
