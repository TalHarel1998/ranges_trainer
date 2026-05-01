# PreflopT — Project Plan

Living document. Update as decisions change.

## 1. Product vision

A personal iPhone app for memorizing and drilling 6-max NLHE preflop ranges.
Fully offline, $0 recurring cost, installed on the owner's personal iPhone only.

### Two training modes

1. **Chart Recall (mode 1).** User picks a chart (e.g., "BTN RFI"), is shown a blank
   13×13 hand grid, and paints each cell with the action they believe is correct.
   App grades the whole grid against the stored chart and shows a diff.

2. **Situation Drill (mode 2).** App deals two hole cards and presents a scenario
   (hero position + prior action). User picks an action from a context-appropriate
   set (e.g., Fold / Open for RFI; Fold / Call / 3-Bet for defense). Immediate
   feedback, score, streaks, weak-spot tracking.

## 2. V1 scope

### In scope

- 6-max cash NLHE ranges only.
- **V1 charts: RFI only** — UTG, MP, CO, BTN, SB (5 charts). BB has no RFI.
- Chart Recall mode.
- Situation Drill mode.
- Basic stats: session score, per-scenario accuracy, hand-class weak-spot list.
- iPhone only, portrait only, iOS 17+ deployment target.

### Deferred to v1.1 / v2 (data exists, not built first)

- Defense charts: BTN defense (vs UTG, MP, CO), SB defense (vs UTG, MP, CO, BTN).
- vs 3-Bet charts.
- vs 4-Bet charts.
- The data directory structure supports these from day one; we just don't build
  the flows until RFI is solid.

### Out of scope (entirely for now)

- Full ring / 9-max, MTT / stack-depth variation.
- In-app chart editor. Charts are authored as JSON in the repo.
- Cloud sync, accounts, iCloud / CloudKit.
- iPad, Apple Watch, widgets.
- Analytics, crash reporting.

## 3. Tech stack & constraints

- **Language:** Swift 6.
- **UI:** SwiftUI, `@Observable` view models (no Combine / `ObservableObject`).
- **Persistence:** SwiftData for user data, bundled JSON for chart data.
- **Min deployment target:** iOS 17.0.
- **Distribution:** Free Apple ID sideload to owner's iPhone. 7-day re-deploy
  cycle accepted. No Apple Developer Program ($99/yr) for v1.
- **No network calls.** No servers, no domains.

## 4. Architecture

Three layers, unidirectional dependencies (Feature → Domain, Feature → Data, Data → Domain).

```
┌─────────────────────────────────────────────────────────┐
│ Feature layer (SwiftUI views + @Observable view models) │
│   ChartBrowser / ChartRecall / SituationDrill / Stats   │
└───────────────┬─────────────────────────┬───────────────┘
                │                         │
┌───────────────▼────────────┐  ┌─────────▼───────────────┐
│ Domain layer (pure Swift)  │  │ Data layer              │
│   Card, HandClass,         │  │   ChartRepository       │
│   Position, Action,        │  │     (bundled JSON)      │
│   Scenario, Chart,         │  │   StatsStore            │
│   ChartAction, grading     │  │     (SwiftData)         │
└────────────────────────────┘  └─────────────────────────┘
```

### 4.1 Domain model (pure Swift, no UIKit / SwiftUI / SwiftData imports)

- `enum Rank: Int, CaseIterable { case two = 2, ..., ace = 14 }`
- `enum Suit: CaseIterable { case spades, hearts, diamonds, clubs }`
- `struct Card: Hashable { let rank: Rank; let suit: Suit }`
- `struct HoleCards: Hashable { let a: Card; let b: Card }` — specific combo.
- `struct HandClass: Hashable, CaseIterable` — the 169 abstract hands.
  - Constructed from two ranks + suitedness (`.pair`, `.suited`, `.offsuit`).
  - Canonical string form: `"AKs"`, `"AKo"`, `"77"`.
  - Can be derived from `HoleCards`.
- `enum Position: CaseIterable { case utg, mp, co, btn, sb, bb }`
- `enum Action: Hashable { case fold, call, open, threeBet, fourBet }`
  - UI-displayed action set depends on scenario (RFI uses `{fold, open}`,
    defense uses `{fold, call, threeBet}`).
- `struct Scenario: Hashable`
  - `hero: Position`
  - `priorAction: PriorAction` — enum describing the situation before hero acts:
    `.firstToAct` (RFI), `.facingOpen(from: Position)`.
  - Stable string key, e.g. `rfi.btn`, `def.btn.vs.utg`.
- `enum ChartAction`
  - `.pure(Action)` — single action, 100% frequency.
  - `.mixed(aggressive: Action, passive: Action)` — deterministic per specific
    `HoleCards` via the **"two black cards" rule** (see §4.5).
  - Helpers: `resolve(for: HoleCards) -> Action`, `contains(_ a: Action) -> Bool`.
- `struct Chart`
  - `scenario: Scenario`
  - `sizing: Sizing` — open bb, 3-bet sizing (metadata, not behavior in v1).
  - `entries: [HandClass: ChartAction]`
  - Missing entries default to `.pure(.fold)`.
- Grading helpers:
  - `grade(chartAction: ChartAction, answered: Action, holeCards: HoleCards?) -> GradeResult`.
  - For `.pure`: correct iff `answered == action`.
  - For `.mixed`: resolved deterministically against the dealt `HoleCards` using
    the two-black-cards rule; correct iff `answered == resolved`.
  - Chart Recall has no specific `HoleCards`, so mixed cells are graded as
    correct if the answered action matches either the aggressive or passive leg
    (UI shows the cell as "mixed"; user paints the dominant action).

### 4.2 Data layer

**Chart storage:** one JSON file per chart, organized by category.

Directory: `PreflopT/Resources/Charts/`

```
Charts/
├── rfi/
│   ├── utg.json
│   ├── mp.json
│   ├── co.json
│   ├── btn.json
│   └── sb.json
├── defense/
│   ├── btn_vs_utg.json
│   ├── btn_vs_mp.json
│   ├── btn_vs_co.json
│   ├── sb_vs_utg.json
│   ├── sb_vs_mp.json
│   ├── sb_vs_co.json
│   └── sb_vs_btn.json
├── vs_3bet/
│   └── …
└── vs_4bet/
    └── …
```

Naming convention: `<category>/<hero_position>[_vs_<villain_position>].json`.
Scenario key derived from the path (`rfi/utg` → `rfi.utg`).

Only `rfi/` is populated and wired into the app for v1. Other folders exist and
can be filled incrementally without schema changes.

Example JSON shape:

```json
{
  "scenario": "rfi.btn",
  "sizing": { "openBB": 2.5 },
  "entries": {
    "AA":  { "type": "pure",  "action": "open" },
    "AKs": { "type": "pure",  "action": "open" },
    "A5s": { "type": "mixed", "aggressive": "open", "passive": "fold" },
    "22":  { "type": "pure",  "action": "open" },
    "72o": { "type": "pure",  "action": "fold" }
  }
}
```

Unspecified hand classes default to `{"type": "pure", "action": "fold"}`, so
source JSON only needs to list non-fold hands.

**ChartRepository**
- `func allCharts() -> [Chart]` — loads all bundled JSON at startup.
- `func chart(for scenario: Scenario) -> Chart?`
- Decoding errors are fatal in debug (surface the bad file fast) and logged in release.

**User data:** SwiftData models.

- `SessionRecord` — one training session, with start/end, mode, scenarios drilled.
- `AnswerRecord` — one question: scenario, hand class, user's action, correct?, timestamp.
- Queries: per-scenario accuracy, worst hand classes, streaks, daily activity.

### 4.3 Feature layer

- `ChartBrowserView` — list of scenarios → `ChartDetailView` showing read-only
  painted 13×13 grid.
- `ChartRecallView` — painter grid + action palette → submit → `ChartRecallResultView`
  with diff (correct / incorrect / missed cells).
- `SituationDrillView` — card display + scenario caption + action buttons →
  instant feedback → next question. Session ends on user exit; summary view.
- `StatsView` — lifetime and recent accuracy, weakest hand classes, streak.

### 4.4 State management

- `@Observable` view models per screen, owning UI state and calling into repos/stores.
- No global singletons; dependencies injected at the root (a small `AppContainer`).
- Navigation: `NavigationStack` with typed destinations.

### 4.5 Mixed-frequency resolution — the "two black cards" rule

Real preflop charts have mixed-frequency hands (e.g., "A5s = 50% open / 50% fold").
We want **deterministic** grading so each specific combo has exactly one right
answer, and the user can learn a concrete rule instead of RNG.

**Rule:** For any mixed hand class with legs `(aggressive, passive)` (where
aggressive > passive in the order `4bet > 3bet > open > call > fold`):

- If **both hole cards are black** (♠ or ♣) → take the **aggressive** action.
- Otherwise → take the **passive** action.

This rule is applied at grading time in Situation Drill (we have the dealt
`HoleCards`) and at display time if we ever want to show "what would I do with
this exact combo."

Chart Recall does not have specific cards — the user paints one action per
hand class. For mixed cells, either leg is accepted as correct; the UI shows a
split-color marker so the user knows the cell is mixed.

Edge cases (e.g., three-way mixes) are not expected in our source data. If any
appear, they are handled manually by reducing to the two dominant actions.

### 4.6 Chart Recall interaction

Requirement: user paints the 13×13 grid manually, cell by cell, from 22 in the
bottom-right up to AA in the top-left (standard poker chart layout).

- Tap an action in the palette to select it (Open / Fold for RFI).
- Tap a cell to paint it with the selected action.
- Drag across cells to paint many at once (essential for fast input on phone).
- Long-press a cell to clear it.
- A "Submit" button grades the grid; cells with no answer count as wrong.
- Result view overlays the correct chart with per-cell diff indicators.

## 5. Project structure (target)

```
ranges_trainer/
├── PreflopT.xcodeproj/
├── PreflopT/
│   ├── App/
│   │   ├── PreflopTApp.swift
│   │   └── AppContainer.swift
│   ├── Domain/
│   │   ├── Card.swift
│   │   ├── HandClass.swift
│   │   ├── Position.swift
│   │   ├── Action.swift
│   │   ├── Scenario.swift
│   │   ├── Chart.swift
│   │   └── Grading.swift
│   ├── Data/
│   │   ├── ChartRepository.swift
│   │   ├── ChartDTO.swift           // Codable mirror of JSON
│   │   └── Stats/
│   │       ├── StatsStore.swift
│   │       ├── SessionRecord.swift
│   │       └── AnswerRecord.swift
│   ├── Features/
│   │   ├── ChartBrowser/
│   │   ├── ChartRecall/
│   │   ├── SituationDrill/
│   │   └── Stats/
│   ├── UI/                           // shared SwiftUI components
│   │   ├── HandGridView.swift
│   │   ├── CardView.swift
│   │   └── ActionPalette.swift
│   └── Resources/
│       ├── Charts/
│       │   ├── rfi/
│       │   ├── defense/
│       │   ├── vs_3bet/
│       │   └── vs_4bet/
│       └── Assets.xcassets
├── PreflopTTests/                    // unit tests (domain, grading, repo)
├── data/                             // raw source charts (not shipped)
├── .kiro/
│   └── plan.md
├── .gitignore
└── README.md
```

## 6. Roadmap

### Phase 0 — Setup
- [x] Init git, push private repo.
- [x] Install full Xcode.
- [ ] Create Xcode project (SwiftUI app, iOS 17+ target, name `PreflopT`).
- [ ] First build to simulator. Commit, push.

### Phase 1 — Domain model + tests
- [ ] Implement `Card`, `HandClass`, `Position`, `Action`, `Scenario`,
      `ChartAction`, `Chart`.
- [ ] Unit tests: 169 hand classes enumerated, `HoleCards → HandClass` mapping,
      canonical string parsing, two-black-cards resolution, grading logic.

### Phase 2 — Chart data import (RFI)
- [ ] Finalize JSON schema (draft done in §4.2).
- [ ] Convert owner's RFI charts into 5 JSON files under `Charts/rfi/`.
      (One at a time, driven from Google Sheets snapshots.)
- [ ] `ChartRepository` loads + decodes all bundled charts at startup.
- [ ] Tests: every expected scenario loads; unspecified cells default to fold.

### Phase 3 — Chart browser
- [ ] `HandGridView` (13×13, AA top-left → 22 bottom-right, color per action,
      split colors for mixed cells).
- [ ] Scenario list → read-only chart display.

### Phase 4 — Chart Recall mode (RFI)
- [ ] Action palette + tap + drag-to-paint interaction (see §4.6).
- [ ] Submit → diff view with per-cell correctness and summary score.

### Phase 5 — Situation Drill mode (RFI)
- [ ] Card renderer (`CardView`).
- [ ] Question generator: random `HoleCards` + random enabled RFI scenario.
- [ ] Answer buttons: Fold / Open.
- [ ] Grading uses two-black-cards rule for mixed hands.
- [ ] Immediate feedback, next-question flow, session summary.

### Phase 6 — Stats & persistence
- [ ] SwiftData schema (`SessionRecord`, `AnswerRecord`).
- [ ] Record answers from Drill and Recall sessions.
- [ ] Stats screen: accuracy per scenario, weakest hand classes, streak,
      recent activity.

### Phase 7 — Polish & install on device
- [ ] App icon, launch screen.
- [ ] Deploy to owner's iPhone via free Apple ID.
- [ ] Accept 7-day re-signing cadence.

### v1.1 — Defense
- [ ] Add defense charts (BTN vs UTG/MP/CO, SB vs UTG/MP/CO/BTN).
- [ ] Extend `Action` palette to include Call and 3-Bet in defense flows.

### v1.2 — vs 3-Bet / vs 4-Bet
- [ ] Add vs_3bet charts and 4-Bet action.
- [ ] Add vs_4bet charts.

### v2 ideas (not committed)
- Configurable "sessions" (e.g., "drill only BTN RFI, 20 questions").
- Spaced-repetition scheduling of weak hand classes.
- In-app chart editing UI.
- iCloud sync.

## 7. Decisions log

- **Scope:** RFI only in v1. Defense, vs 3-Bet, vs 4-Bet deferred to v1.1/v1.2.
- **Data format:** one JSON file per chart, organized into
  `rfi/`, `defense/`, `vs_3bet/`, `vs_4bet/` under `Resources/Charts/`.
- **Mixed frequencies:** deterministic via the two-black-cards rule (§4.5).
  Unusual mixes handled manually in the JSON.
- **BB RFI:** excluded (BB never opens).
- **iOS target:** 17+ (owner's device runs iOS 26).
- **Chart Recall interaction:** tap-to-paint with drag support, bottom-right 22
  to top-left AA (§4.6).
- **Polish / icon / launch screen:** deferred to Phase 7, after core flows work.
