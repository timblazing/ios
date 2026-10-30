# ios

[timblazing/ios](https://github.com/timblazing/ios) is my hub for iOS app development and projects for a jailbroken **iPad mini 2 running iOS 10.3.3** (A7, TNS Sockport, AppSync Unified). It includes everyday apps, companion tools, and games built for this device. Modern iOS devices are not the target.

## Apps

| App | Version | Installable release |
|---|---|---|
| [Paint](apps/paint/) | 2.0.0 | [IPA](apps/paint/dist/Paint-2.0.0.ipa) · [checksums](apps/paint/dist/SHA256SUMS) |
| [T3 Code](apps/t3code/) | 0.3.1 | [IPA](apps/t3code/dist/T3Code-0.3.1.ipa) · [checksums](apps/t3code/dist/SHA256SUMS) |
| [TV](apps/iptv/) | 0.3.2 | [IPA](apps/iptv/dist/IPTV-0.3.2.ipa) · [checksums](apps/iptv/dist/SHA256SUMS) |

## Games

| Game | Version | Installable release |
|---|---|---|
| [Solitaire](games/solitaire/) | 2.4.1 | [IPA](games/solitaire/dist/Solitaire-2.4.1.ipa) · [checksums](games/solitaire/dist/SHA256SUMS) |
| [Wordle](games/wordle/) | 1.0.0 | [IPA](games/wordle/dist/Wordle-1.0.0.ipa) · [checksums](games/wordle/dist/SHA256SUMS) |
| [Rent Trivia](games/rent-trivia/) | 1.1.1 | [IPA](games/rent-trivia/dist/RentTrivia-1.1.1.ipa) · [checksums](games/rent-trivia/dist/SHA256SUMS) |

Solitaire and Paint are offline. Wordle fetches and caches daily answers from the NYT. Rent Trivia can optionally stream a movie from a user-configured Jellyfin server; public packages contain no server credentials. The T3 Code companion connects to a T3 Code host on another computer. TV plays live channels from a user-configured Dispatcharr server on the home network.

For “IPTV backlog/next steps,” start with [TV backlog](apps/iptv/docs/BACKLOG.md) and [handoff](apps/iptv/docs/HANDOFF.md). TV 0.3.2 is installed on the physical iPad; the agreed short home checks passed by owner report. Physical USB fallback and extended coverage remain unverified.

## Stack and layout

Objective-C and UIKit, with SpriteKit where appropriate, built with Theos on macOS for ARM64 and an iOS 10.0 deployment target. Build against the iPhoneOS 16.5 SDK; current Xcode cannot link the old 10.3 SDK. See [the shared development guide](docs/ipad-mini-2-ios10-game-development-guide.md).

- `games/<name>/` and `apps/<name>/` each hold a self-contained project: `Makefile`, `control`, `Resources/`, `scripts/`, tests, and release output. Build and package inside that folder.
- `docs/` holds shared notes, including [personal research to-dos](docs/PERSONAL_TODO.md). `.clang-format` applies throughout.
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
