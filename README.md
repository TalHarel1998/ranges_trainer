# Ranges Trainer

Memorize and train 6-max preflop poker charts. Two front-ends share the same chart
JSON (`PreflopT/PreflopT/Resources/Charts/`):

- **Web app (PWA)** in `web/` — install on iPhone from Safari via "Add to Home Screen".
  https://talharel1998.github.io/ranges_trainer/
- **iOS app** (Swift/SwiftUI) in `PreflopT/`.

**Start with [PROJECT_KNOWLEDGE.md](PROJECT_KNOWLEDGE.md)** — layout, commands,
chart format, deploy, iPhone install, status, and decisions.

Quick commands:

```
node --test web/tests/*.test.mjs                                   # web tests
python3 -m http.server 8000 --bind 127.0.0.1 --directory web      # run locally
```

## iOS app (original notes)

An iOS app for memorizing and training preflop poker charts.

## Status

Early development — project scaffolding in progress.

## Stack

- Swift / SwiftUI
- iOS (target TBD)

## Planned Features

- Position-based opening ranges (UTG, MP, CO, BTN, SB, BB)
- Interactive 13×13 hand grid
- Quiz / training mode with progress tracking
- Customizable chart sets
