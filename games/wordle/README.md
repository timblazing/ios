# Wordle for iPad mini 2

A close copy of the NYT Wordle (2022 look) in Objective-C and UIKit. Targets ARM64 and iOS 10.0 or later, all four orientations.

## No word list

The app ships with no words at all:

- **Answers** come from the New York Times' public endpoint, `https://www.nytimes.com/svc/wordle/v2/<yyyy-MM-dd>.json`, which returns that day's `solution`. It's free and needs no key. Every answer fetched is cached in `NSUserDefaults`, and the next 15 days are prefetched on launch, so the daily puzzle keeps working for about two weeks without Wi-Fi.
- **Guesses** are checked with `UITextChecker`, the iPad's built-in spelling dictionary (`en_US`). Any past answer the app has cached is also accepted. The dictionary is a bit looser and a bit different from Wordle's own list, so the occasional odd word gets in or out.

Wordle uses the network only to fetch puzzle answers; progress and statistics stay on the device.

## Play

- Today's puzzle uses the iPad's local date, numbered like the real one (No. 0 was 19 June 2021).
- Menu (top left): Today's Wordle, or Practice, a random puzzle from the archive. Practice needs Wi-Fi unless some past answers are already cached, and doesn't count toward statistics.
- Help, Statistics, and Settings are on the right. Settings has Hard Mode (can only be turned on before the first guess), Dark Theme, and High Contrast Mode.
- Tiles pop as you type, flip to reveal, the row shakes on a rejected guess, and a win bounces. Reduce Motion skips the flip and bounce.
- Share copies the emoji grid to the clipboard.
- A Bluetooth keyboard works: letters, Return, Delete.

Progress, statistics, and settings save locally. The daily puzzle rolls over at midnight, including while the app is open.

**Release:** [Wordle-1.0.0.ipa](dist/Wordle-1.0.0.ipa), Debian package in `packages/`, and [checksums](dist/SHA256SUMS).

## Build

```sh
make package FINALPACKAGE=1 -j4   # .deb in packages/
scripts/package-ipa.sh            # .ipa in dist/
scripts/test-rules.sh             # model tests (evaluation, hard mode, stats, calendar)
```

`scripts/make-art.py` drew the icon master (`Resources/Icon/icon-1024.png`) and the plain launch images; `make` turns the master into the bundle icon sizes. Building with `-DWORDLE_DEBUG` (simulator only) adds a driver for screenshots: `WORDLE_TYPE="crane,"` types (a comma is Enter), `WORDLE_PANEL=showStats` opens a panel, `WORDLE_PRACTICE=1` starts practice.

## Layout

```
Application/Game/       Foundation-only model: WordleGame, WordleStats, PuzzleCalendar (unit tested)
Application/Services/   WordSource: fetches and caches answers
Application/UI/         Theme, Icons, TileView, BoardView, KeyboardView, Panel and its panels
```
