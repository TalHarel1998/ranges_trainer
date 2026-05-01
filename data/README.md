# Raw chart data

This directory holds the **source snapshots** (images, spreadsheets, PDFs) that
the processed JSON charts in `PreflopT/Resources/Charts/` are derived from.

Not shipped in the app binary.

## Layout

- `rfi/` — 5 files, one per hero position: `utg`, `mp`, `co`, `btn`, `sb`.
- `defense/` — BTN and SB defense charts vs each earlier opener.
- `vs_3bet/` — hero open, villain 3-bets, hero response.
- `vs_4bet/` — hero 3-bets, villain 4-bets, hero response.

## Naming

Free-form during import; final JSON in `PreflopT/Resources/Charts/` uses the
canonical names (see `.kiro/plan.md` §4.2).

## Image format

Any format is fine (PNG, JPEG, HEIC, screenshots). Kiro reads them directly
to transcribe into JSON.
