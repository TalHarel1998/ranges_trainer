# Project Knowledge Base — Ranges Trainer

Read this first. It is the single place for how this repo works, current status,
commands, and decisions. Keep it up to date when you change something that a future
person or agent would need to know.

Last updated: 2026-11-05 (web app deployed to GitHub Pages).

## 1. What this repo is

A personal trainer for memorizing **6-max NLHE cash preflop charts** (GG ranges).
It has two front-ends that share the same chart data:

| App | Folder | Status | How it runs |
|---|---|---|---|
| iOS app "PreflopT" (Swift/SwiftUI) | `PreflopT/` | Working; sideloaded with a free Apple account, so it expires every 7 days | Xcode → device |
| Web app (PWA) | `web/` | Working; the replacement for daily use | GitHub Pages → Safari "Add to Home Screen" |

GitHub: https://github.com/TalHarel1998/ranges_trainer (public).
Web URL (once Pages is enabled): https://talharel1998.github.io/ranges_trainer/

## 2. Repo layout

```
PreflopT/                         iOS app (Xcode project)
  PreflopT/Domain/                pure Swift logic (reference for the web port)
  PreflopT/Features/              SwiftUI screens (browser, recall, editor, settings)
  PreflopT/Resources/Charts/      ★ chart JSON files — single source of truth
  PreflopTTests/                  Swift unit tests
data/                             raw source images the JSON was transcribed from
web/                              PWA (plain HTML/CSS/JS, no build, no npm)
  index.html, styles.css
  manifest.webmanifest            home-screen metadata
  sw.js                           service worker (offline + updates)
  charts -> ../PreflopT/PreflopT/Resources/Charts   (symlink, committed)
  js/domain.js                    pure logic (parser, combos, grading, unified RFI)
  js/charts.js                    hardcoded list of chart files + loader
  js/colors.js                    palettes, localStorage, text contrast
  js/app.js                       UI: hash router, views, drag-to-paint
  tests/domain.test.mjs           node:test tests
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

### Adding or changing a chart

1. Edit or add the JSON under `PreflopT/PreflopT/Resources/Charts/`.
2. **New file only:** add its path to **both** `web/js/charts.js` (`CHART_FILES`)
   and `web/sw.js` (`CHART_FILES`). Browsers can't list directories, and a file
   missing from `sw.js` won't work offline. The test
   `CHART_FILES ... has 23 unique entries` must be updated with the new count.
3. Run `node --test web/tests/*.test.mjs`.
4. Push to `main`. The web app updates on the next launch. The iOS app picks the
   file up on the next Xcode build (synchronized group).

## 5. Web app architecture

- **No build step.** ES modules served as-is. No dependencies, CDNs, or external
  requests.
- **Routing:** hash routes, so no server config is needed:
  `#/`, `#/rfi`, `#/category/<id>`, `#/chart/<scenarioKey>`,
  `#/recall/<scenarioKey>`, `#/colors`, `#/rfi-colors`.
- **Read-only charts.** There is no chart editor on the web, on purpose: the JSON
  in git is the only source of truth. Color preferences are saved per device in
  localStorage (`preflopt.palette.v1`, `preflopt.rfiPalette.v1`).
- **Drag-to-paint (recall):** Pointer Events + `document.elementFromPoint`.
  A gesture that starts on a cell already painted with the selected option erases.
  Only `.grid.interactive` has `touch-action: none`. Read-only grids must keep
  page scrolling.
- **Service worker (`sw.js`):**
  - It precaches the app shell, the 23 charts and the icons.
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

## 6. Using the web app on iPhone

One-time GitHub setup: repo **Settings → Pages → Build and deployment → Source:
GitHub Actions**. Then push or merge to `main`, and wait for the
"Deploy to GitHub Pages" run under the **Actions** tab to turn green.

On the iPhone:
1. Open **Safari**. It must be Safari, because other browsers on iOS can't add web apps.
2. Go to https://talharel1998.github.io/ranges_trainer/
3. Tap **Share** (square with arrow) → **Add to Home Screen** → keep the name
   "PreflopT" and make sure **Open as Web App** is on (iOS 26) → **Add**.
4. Launch it from the home-screen icon once while online. After that it works
   offline.

To update, push to `main`, then close and reopen the app (sometimes twice).
To remove it, long-press the icon → Remove App. Color settings are stored
on the device, inside the home-screen app's own storage.

## 7. Status and roadmap

Done:
- iOS app: RFI, defense, vs 3-bet, vs 4-bet charts, browser, unified RFI view,
  Chart Recall, chart editor (overrides), color settings.
- Web app: feature parity with the iOS app except the editor. Spec F1–F9 in
  `web/SPEC.md` are all verified by the reviewer, using unit tests plus
  headless-Chrome tests of touch painting, offline, update flow and sub-path
  hosting.
- Deployed: merged to `main` (992e39a), GitHub Pages source = GitHub Actions,
  live at https://talharel1998.github.io/ranges_trainer/

Next / open:
- Install on the iPhone (section 6).
- Workflow actions target Node 20, which GitHub has deprecated and now forces
  onto Node 24. It still works; bump the actions to newer major versions when
  they're available.
- Situation Drill mode (deal two cards, pick the action). Planned in `.kiro/plan.md`
  Phase 5, not built on either platform.
- Stats / weak-spot tracking.
- Optional: darker "call" green for pill contrast (currently 2.7:1).

## 8. Decisions log

- **Web instead of App Store or paid developer account:** avoids the 7-day
  re-sign cycle at zero cost. The iOS app stays in the repo as reference and fallback.
- **Same repo, shared JSON via symlink:** one source of truth for chart data.
- **No web chart editor:** each browser would hold its own copy of the charts,
  separate from git. Edit the JSON instead.
- **Plain JS, no framework or build:** small app; nothing to keep updated;
  GitHub Pages hosts it directly.
- **Recall erase-on-drag:** a web addition. On iOS the only way to unpaint is Clear.
- **Unified RFI page links to per-position recall:** a web addition (iOS has no
  entry point to per-position RFI recall).
- **Public site:** the repo is public, so the Pages URL is public too. Anyone with
  the link can see the charts. There are no secrets or personal data in the app.

## 9. How the web app was built (process)

Built by a 3-role agent team: an orchestrator wrote `web/SPEC.md` with
acceptance criteria, a coder implemented it, and a reviewer tested every AC
independently. Review took 3 rounds. Round 1 found CI test glob and touch
scrolling problems. Round 2 found the service worker served stale builds through
the HTTP cache. Round 3 approved. For future changes, update `SPEC.md` first, then
code, then tests.
