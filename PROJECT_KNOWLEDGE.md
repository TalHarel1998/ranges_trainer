# Project Knowledge Base — Ranges Trainer

Read this first. It is the single place for how this repo works, current status,
commands, and decisions. Keep it up to date when you change something that a future
person or agent would need to know.

Last updated: 2026-11-05 (in-app editing of charts and colors via GitHub).

## 1. What this repo is

A personal trainer for memorizing **6-max NLHE cash preflop charts** (GG ranges).
It has two front-ends that share the same chart data:

| App | Folder | Status | How it runs |
|---|---|---|---|
| iOS app "PreflopT" (Swift/SwiftUI) | `PreflopT/` | Working; sideloaded with a free Apple account, so it expires every 7 days | Xcode → device |
| Web app (PWA) | `web/` | Working; the replacement for daily use | GitHub Pages → Safari "Add to Home Screen" |

GitHub: https://github.com/TalHarel1998/ranges_trainer (public).
Web URL: https://talharel1998.github.io/ranges_trainer/

**Branching:** work directly on `main`; it is the only branch. Every push to
`main` deploys the web app.

## 2. Repo layout

```
PreflopT/                         iOS app (Xcode project)
  PreflopT/Domain/                pure Swift logic (reference for the web port)
  PreflopT/Features/              SwiftUI screens (browser, recall, editor, settings)
  PreflopT/Resources/Charts/      ★ chart JSON files — single source of truth
  PreflopTTests/                  Swift unit tests
data/                             raw source images the JSON was transcribed from
web/                              PWA (plain HTML/CSS/JS, no build, no npm)
  index.html                      includes the Content-Security-Policy meta tag
  styles.css
  manifest.webmanifest            home-screen metadata
  sw.js                           service worker (offline + updates)
  palette.json                    ★ web app colors — source of truth (edited in-app or in git)
  charts -> ../PreflopT/PreflopT/Resources/Charts   (symlink, committed)
  js/domain.js                    pure logic (parser, combos, grading, unified RFI)
  js/charts.js                    hardcoded list of chart files + loader
  js/colors.js                    palette defaults, palette.json parse/serialize, contrast
  js/serialize.js                 pure: range-string writer, chart JSON writer, UTF-8 base64
  js/github.js                    GitHub REST client (test token, get file, put file)
  js/store.js                     token + pending-writes in localStorage
  js/config.js                    repo owner/name/branch, app path ↔ repo path mapping
  js/app.js                       UI: hash router, views, drag-to-paint, editor
  tests/*.test.mjs                node:test tests (domain, serialize, github, store)
  tools/make_icons.mjs            regenerates icons/ (pure Node, no deps)
  icons/                          apple-touch-icon 180, 192, 512 PNG
  SPEC.md                         feature spec + acceptance criteria for the web app
.github/workflows/pages.yml       tests + deploys web/ to GitHub Pages on push to main
.kiro/plan.md                     original iOS project plan and decisions log
PROJECT_KNOWLEDGE.md              this file
```

## 3. Commands

All from the repo root.

| Task | Command |
|---|---|
| Get phone edits onto the Mac | `git pull` (do this **before** editing on the Mac) |
| Run web tests | `node --test web/tests/*.test.mjs` (a directory arg fails on Node 22) |
| Run web app locally | `python3 -m http.server 8000 --bind 127.0.0.1 --directory web` then open http://127.0.0.1:8000/ |
| Regenerate icons | `node web/tools/make_icons.mjs` |
| Deploy web app | push to `main` (workflow runs tests, then publishes) |
| Run iOS tests | Xcode, or `xcodebuild test`; inspect failures with `xcrun xcresulttool get test-results tests` |

The local server is loopback-only on purpose. To try it on the phone, use the
deployed GitHub Pages URL, not a LAN bind.

## 4. Chart data format

One JSON file per chart in `PreflopT/PreflopT/Resources/Charts/<group>/`. Ranges
use the standard range-string syntax: `AA`, `AKs`, `AKo`, `22+` (22–AA),
`A2s+` (A2s–AKs), `K9o+` (K9o–KQo), comma separated.

| chartType | Fields (each a range string) | Meaning |
|---|---|---|
| `rfi` | `range`, optional `openSize`, `note` | open |
| `defense` | `threeBet`, `mixed3betCall`, `mixed3betFold`, `call` | facing an open |
| `vs3bet` | `fourBet`, `mixed4betCall`, `call` | hero opened, faced a 3-bet |
| `vs4bet` | `fiveBet`, `mixed5betCall`, `call` | hero 3-bet, faced a 4-bet |

Any hand not listed is a fold. A hand in two fields of one chart is an error (both
apps reject it).

Scenario keys: `rfi.utg`, `def.bb.vs.btn`, `vs3b.utg.vs.ip` (ip/oop = 3-bettor
group), `vs4b.btn.vs.co`.

**Mixed cells** use the *two-black-cards rule*: take the aggressive action when
both hole cards are black (♠/♣), otherwise the passive one. Legends and row counts
put the full combo count of a mixed hand in the "mix" bucket.

### How the app writes chart JSON (`js/serialize.js`)

- Only fields whose hand set changed are rewritten. Unchanged fields keep their
  exact original text, and key order is preserved, so git diffs stay small.
  Saving with no edits produces the identical file, which is tested for all 23 charts.
- Rewritten fields use a compact canonical form: pairs first (`77+` for a run
  ending at AA), then suited by high card (`A2s+` for a run ending just below the
  high card), then offsuit, joined by `", "`. This is the same syntax the iOS
  parser reads.
- A field that becomes empty stays as `""`. A field that didn't exist yet is
  added after the existing range fields. The output is 2-space JSON with a
  trailing newline.

### Adding a new chart file (Mac only)

The in-app editor only edits existing charts. To add a new one:

1. Add the JSON under `PreflopT/PreflopT/Resources/Charts/`.
2. Add its path to **both** `web/js/charts.js` (`CHART_FILES`) and `web/sw.js`
   (`CHART_FILES`). Browsers can't list directories, and a file missing from
   `sw.js` won't work offline. Update the count in the test
   `CHART_FILES ... has 23 unique entries`.
3. iOS: add a line to `BundledChartRepository.manifest` in
   `PreflopT/PreflopT/Data/ChartRepository.swift`.
4. Run `node --test web/tests/*.test.mjs`, then push to `main`.

## 5. Editing from the iPhone (or any browser)

Charts and colors can be edited in the web app and saved straight to GitHub.

**One-time setup:**
1. On github.com: profile picture → Settings → Developer settings → Personal
   access tokens → **Fine-grained tokens** → Generate new token.
   - Repository access: **Only select repositories → `ranges_trainer`**
   - Permissions: Repository → **Contents: Read and write**. Leave everything else as No access.
   - Expiration: your choice. When it expires, generate a new one and paste it again.
2. In the app: Home → **GitHub** → paste the token → **Save & test**. It must say
   "Connected — can write to ranges_trainer".

**Editing a chart:**
1. Open the chart and tap **Edit**. The button only appears once a token is
   saved. For RFI, open the per-position chart from the RFI page's position buttons.
2. Pick an action, then tap or drag to paint. Starting a drag on a cell already
   set to the selected action paints Fold instead. Changed cells show a dot.
3. Tap **Save**, check the summary (e.g. "Open: +A9o · Fold: +T7s"), then **Commit**.
4. The edit shows in the app immediately. Other devices get it after the deploy,
   about a minute later.

**Editing colors:** use Colors or Edit RFI Colors, then **Save colors to GitHub**.
Without a token, the color pickers are disabled.

**How it works:**
- The app reads the file through the GitHub contents API to get its `sha`, then
  PUTs the new content with that `sha` to `main`.
- If the file changed on GitHub in the meantime (an edit from the Mac or another
  device), GitHub rejects the save. The app says so and keeps your edits on
  screen. Reopen the editor and re-apply them.
- After a save, the new file text is also kept in localStorage
  (`preflopt.pendingWrites.v1`) for up to 30 minutes, until the deployed site
  catches up. This keeps a fresh edit from appearing to revert if you reopen the
  app before the deploy finishes. A side effect is that a Mac edit to the same
  file within those 30 minutes is hidden on that phone until the deployed file
  matches or the 30 minutes pass.
- Commit messages: `Edit <chart title> from web app`, `Update colors from web app`.

**Mac ↔ phone (both directions go through GitHub):**
- Phone → GitHub happens automatically on Commit.
- Mac → GitHub is `git push`.
- **Always run `git pull` before editing on the Mac.** Otherwise `git push` is
  rejected ("fetch first"). Pull, then push again. If the same lines changed on
  both sides, git asks you to resolve the conflict.
- The iOS app gets chart changes on the next Xcode build after `git pull`. iOS
  colors are separate: `palette.json` is web-only.

**Security model:**
- The site is public, but writing needs the token, which exists only on your
  device. It is stored in localStorage `preflopt.githubToken.v1`, inside the
  home-screen app's storage.
- The token is sent only to `https://api.github.com`. It is never shown again
  after saving (only "•••• last 4"), never logged, and scrubbed from error text.
- The service worker never intercepts or caches cross-origin requests, so GitHub
  responses are never cached.
- The CSP (`index.html`) allows connections only to the site itself and
  `api.github.com`, and allows no inline scripts. All dynamic text is set with
  text nodes, never `innerHTML`.
- **Lost phone or leaked token:** delete the token on GitHub (Settings → Developer
  settings → Fine-grained tokens). It stops working immediately.

## 6. Web app architecture

- **No build step.** ES modules served as-is. No dependencies or CDNs. The only
  external origin is `api.github.com`, and only when a token is set.
- **Routing:** hash routes, so no server config is needed:
  `#/`, `#/rfi`, `#/category/<id>`, `#/chart/<scenarioKey>`,
  `#/recall/<scenarioKey>`, `#/edit/<scenarioKey>`, `#/github`, `#/colors`,
  `#/rfi-colors` (Back → Colors), `#/rfi-colors/rfi` (opened from the RFI page;
  Back → RFI).
- **Data loading:** at boot the app fetches all 23 chart files and `palette.json`
  as text, applies any pending writes (section 5), then parses them. A missing or
  invalid `palette.json` falls back to the built-in defaults in `colors.js`.
- **Drag-to-paint (recall and editor):** Pointer Events + `document.elementFromPoint`.
  A gesture that starts on a cell already painted with the selected option erases.
  Only `.grid.interactive` has `touch-action: none`. Read-only grids must keep
  page scrolling.
- **Service worker (`sw.js`):**
  - It precaches the app shell (including all `js/*` modules and `palette.json`),
    the 23 charts and the icons. Add new modules to `APP_SHELL`.
  - Navigations and `.js`/`.css`/`.json`/`.webmanifest` are network-first. They
    use a 3 s timeout and `cache: 'no-cache'`, because GitHub Pages sends
    `max-age=600` and the plain HTTP cache would otherwise serve the old build.
    If the network fails, the cached copy is used.
  - Icons are cache-first.
  - The cache name is `preflopt-__BUILD__`, and the workflow replaces
    `__BUILD__` with the short commit SHA. Old caches are deleted on activate.
  - A new deploy shows on the **next launch** of the home-screen app. A same-tab
    reload within 10 minutes may still reuse in-memory JS, which is a known
    limitation and not a bug.
- **Deploy:** the workflow copies `web/` with `cp -RL`, which turns the `charts`
  symlink into real files, and drops `SPEC.md`, `tests/` and `tools/`.
- **iPhone requirements:** iOS 15+ (uses `aspect-ratio`; `color-mix()` only on
  error and destructive styling).

## 7. Using the web app on iPhone

GitHub Pages is already enabled (Settings → Pages → Source: GitHub Actions).

On the iPhone:
1. Open **Safari**. It must be Safari, because other browsers on iOS can't add web apps.
2. Go to https://talharel1998.github.io/ranges_trainer/
3. Tap **Share** (square with arrow) → **Add to Home Screen** → keep the name
   "PreflopT" and make sure **Open as Web App** is on (iOS 26) → **Add**.
4. Launch it from the home-screen icon once while online. After that it works
   offline. Editing needs a connection.

To update, push to `main`, then close and reopen the app (sometimes twice).
To remove it, long-press the icon → Remove App. This also deletes the token from
the phone.

## 8. Status and roadmap

Done:
- iOS app: RFI, defense, vs 3-bet, vs 4-bet charts, browser, unified RFI view,
  Chart Recall, chart editor (on-device overrides), color settings.
- Web app: feature parity with the iOS app, plus editing that commits to GitHub
  (charts and colors). Spec F1–F15 in `web/SPEC.md` are verified by the reviewer:
  83 unit tests, about 19k serializer checks (including a port of the Swift
  parser), and 160 headless-Chrome checks against a mocked GitHub API covering
  token handling, the editor, conflicts, errors, CSP, offline mode and updates.
- Deployed and installed on the owner's iPhone.

Next / open:
- First real edit from the phone with a real token. Only the mocked API has
  been tested, so this also confirms GitHub's CORS behavior.
- Workflow actions target Node 20, which GitHub has deprecated and now forces
  onto Node 24. It still works; bump the actions to newer major versions when
  they're available.
- Situation Drill mode (deal two cards, pick the action). Planned in `.kiro/plan.md`
  Phase 5, not built on either platform.
- Stats / weak-spot tracking.
- Optional: editing `openSize` / `note` in the app (currently preserved as-is).
- Optional: darker "call" green for pill contrast (currently 2.7:1).

## 9. Decisions log

- **Web instead of App Store or paid developer account:** avoids the 7-day
  re-sign cycle at zero cost. The iOS app stays in the repo as reference and fallback.
- **Same repo, shared JSON via symlink:** one source of truth for chart data.
- **GitHub is the database:** in-app edits commit to `main` through the contents
  API, so there is no backend to run. Every change is a git commit with history
  and easy revert. The owner is the only user. The chosen access model is a
  fine-grained token limited to this repo's contents.
  (An earlier version had no web editor at all, because browser-local copies
  would have drifted from git.)
- **Colors in `web/palette.json`:** the same colors on every device, with the
  repo as the source of truth. The old per-device localStorage colors are deleted
  on boot.
- **Plain JS, no framework or build:** small app; nothing to keep updated;
  GitHub Pages hosts it directly.
- **Recall erase-on-drag:** a web addition. On iOS the only way to unpaint is Clear.
- **Unified RFI page links to the per-position chart views:** a web addition,
  giving access to Practice and Edit for each position.
- **Public site:** the repo is public, so the Pages URL is public too. Anyone with
  the link can see the charts. Only token holders can write.

## 10. How the web app was built (process)

Built by a 3-role agent team: an orchestrator writes `web/SPEC.md` with
acceptance criteria, a coder implements it, and a reviewer tests every AC
independently (headless Chrome over CDP, with GitHub mocked by request
interception; never a real token).
- **v1 (F1–F9):** 3 review rounds. They found the CI test glob, touch scrolling,
  and the service worker serving stale builds through the HTTP cache.
- **Editing (F10–F15):** 2 review rounds. They found that Colors Save never
  enabled, the conflict and 401 messages, an editor load race, double-submit,
  and toasts blocking taps.

For future changes, update `SPEC.md` first, then code, then tests.
