# ios-games

Native games and apps for a jailbroken **iPad mini 2 running iOS 10.3.3** (A7, TNS Sockport, AppSync Unified). Modern iOS devices are not the target.

## Games

| Game | Version | Installable release |
|---|---|---|
| [Solitaire](games/solitaire/) | 2.4.1 | [IPA](games/solitaire/dist/Solitaire-2.4.1.ipa) · [checksums](games/solitaire/dist/SHA256SUMS) |
| [Wordle](games/wordle/) | 1.0.0 | [IPA](games/wordle/dist/Wordle-1.0.0.ipa) · [checksums](games/wordle/dist/SHA256SUMS) |
| [Rent Trivia](games/rent-trivia/) | 1.1.1 | [IPA](games/rent-trivia/dist/RentTrivia-1.1.1.ipa) · [checksums](games/rent-trivia/dist/SHA256SUMS) |

## Apps

| App | Version | Installable release |
|---|---|---|
| [Paint](apps/paint/) | 2.0.0 | [IPA](apps/paint/dist/Paint-2.0.0.ipa) · [checksums](apps/paint/dist/SHA256SUMS) |
| [T3 Chat](apps/t3code/) | 0.2.1 | [IPA](apps/t3code/dist/T3Chat-0.2.1.ipa) · [checksums](apps/t3code/dist/SHA256SUMS) |

Solitaire and Paint are offline. Wordle fetches and caches daily answers from the NYT. Rent Trivia can optionally stream a movie from a user-configured Jellyfin server; public packages contain no server credentials. T3 Chat connects to a T3 Code host on another computer.

## Stack and layout

Objective-C and UIKit, with SpriteKit where appropriate, built with Theos on macOS for ARM64 and an iOS 10.0 deployment target. Build against the iPhoneOS 16.5 SDK; current Xcode cannot link the old 10.3 SDK. See [the shared development guide](docs/ipad-mini-2-ios10-game-development-guide.md).

- `games/<name>/` and `apps/<name>/` each hold a self-contained project: `Makefile`, `control`, `Resources/`, `scripts/`, tests, and release output. Build and package inside that folder.
- `docs/` holds shared notes. `.clang-format` applies throughout.
- Release `.ipa`, `.deb`, and `dist/SHA256SUMS` files are committed. Generated build intermediates and private settings stay local.

```sh
export THEOS=~/theos
cd games/wordle  # or apps/paint, games/rent-trivia, etc.
make package FINALPACKAGE=1 -j4
scripts/package-ipa.sh
scripts/test-rules.sh  # where provided
```

## Install on the iPad

With TNS Sockport active and AppSync Unified installed, connect over USB or keep the iPad awake and unlocked on the same Wi-Fi as this Mac:

```sh
./install.sh
```

Choose a game or app, select a build from its `dist/` folder, and confirm the app, device, and installed version. “Select IPA file...” also accepts another IPA. Wi-Fi installs require Finder's “Show this iPad when on Wi-Fi” setting, enabled once over USB.

The macOS installer uses bundled libimobiledevice tools adapted from Legacy iOS Kit; see [their notice](tools/libimobiledevice/macos/NOTICE.md). Device-only checks are documented in each project's `Tests/DEVICE_CHECKLIST.md` and are separate from build/model-test results.
