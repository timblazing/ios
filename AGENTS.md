# AGENTS.md

Notes for agents working in this repo. Read this before changing code or the build.

## What this is

Small native games and apps for one device: a jailbroken **iPad mini 2** (A7, 1 GB RAM, 2048×1536 Retina at 326 ppi, 1024×768 points) on **iOS 10.3.3**, jailbroken with TNS Sockport and AppSync Unified. Modern iOS devices are not a target. Solitaire and Paint are offline. Wordle fetches puzzle answers; Rent Trivia optionally streams from a user-configured Jellyfin server; T3 Mini connects to a T3 Code host. No ads or analytics. Never commit credentials or private server configuration.

```
games/<name>/      one self-contained Theos project per game (Makefile, control, Resources/, scripts/, Tests/, docs/)
apps/<name>/       one self-contained Theos project per non-game app
docs/              shared notes, including the original stack research
install.sh         interactive IPA installer for the USB-connected iPad (macOS)
tools/             shared tooling: bundled libimobiledevice binaries for install.sh
.clang-format      applies to all games
```

Build, test, and package from inside `games/<name>/` or `apps/<name>/`. Each game's README is the source of truth for that game. Specs live in `games/<name>/docs/`.

## Stack

Objective-C + UIKit + SpriteKit, built with Theos. No Swift: it would mean shipping a Swift runtime to iOS 10 for no gain.

Picking a stack for a new game:

| Game type | Use |
|---|---|
| Mostly UI and logic (Sudoku, 2048, Minesweeper, word games) | UIKit only; SpriteKit optional |
| Cards, drag-and-drop, arcade (Solitaire, Snake, Breakout, Flappy Bird) | SpriteKit board with UIKit menus, settings, and alerts |
| Physics (pool, pinball, air hockey) | SpriteKit physics: `SKPhysicsBody`, impulses, contact delegate |
| Top-down or pseudo-3D (Mode 7) racing | SpriteKit plus custom perspective math |
| Real 3D | SceneKit, only if truly needed |

GameplayKit (state machines, seeded randomness, pathfinding) and AVFoundation (music) are available when a game needs them. SpriteKit sound actions cover simple effects. Avoid legacy Unity, Cocos2d-x, and WKWebView/Phaser unless the user asks: they add toolchain weight for no benefit at this scale.

## Building

Theos is at `~/theos` (`export THEOS=~/theos`), installed with the official macOS installer alongside current Xcode.

```sh
cd games/<name>
make package FINALPACKAGE=1 -j4   # .deb in packages/
scripts/package-ipa.sh            # .ipa in dist/, version read from control
scripts/test-rules.sh             # model tests, if the game has them
```

**SDK:** build against the iPhoneOS 16.5 SDK with an iOS 10.0 deployment target: `TARGET = iphone:clang:16.5:10.0`. Don't switch back to the 10.3 SDK (`~/theos/sdks/iPhoneOS10.3.sdk` is installed but unusable). Its `.tbd` stubs list arm64 and x86_64 under one `ios` platform, and the current Xcode linker treats them as simulator libraries and refuses to link. `-ld_classic` no longer exists. The deployment target, not the SDK, decides where the app runs.

After a build, confirm the target:

```sh
vtool -show-build .theos/_/Applications/<App>.app/<App>   # expect LC_VERSION_MIN_IPHONEOS, version 10.0
```

**Flags:** keep `-fno-exceptions -fno-objc-exceptions` (no exceptions are used) and `-Wall -Wextra`. Fix warnings, don't suppress them. In particular, `-Wunguarded-availability-new` is the safety net that flags iOS 11+ APIs. The `-multiply_defined is obsolete` linker warning comes from Theos and is harmless.

**Release:** bump both `control` `Version` and `Info.plist` `CFBundleShortVersionString`/`CFBundleVersion`. Update `dist/SHA256SUMS`. `.deb` and `.ipa` artifacts are committed on purpose (see `.gitignore`).

## Installing on the iPad

Run `./install.sh` from the repo root with the iPad on USB or on the same Wi-Fi as the Mac, TNS Sockport active, and AppSync Unified installed. It's an interactive menu: pick a game or app (from `games/` or `apps/`) or "Select IPA file..." for a Finder picker, pick a build from that game's `dist/`, then confirm. The confirm screen shows the app, the device, and the installed version. It's a slimmed-down version of Legacy iOS Kit's App Management → Install IPA (ideviceinstaller), using the same macOS binaries, copied to `tools/libimobiledevice/macos/` (see `NOTICE.md` there). The `.deb` also works (`dpkg -i`, or Filza). If the home screen icon is stale, run `uicache` as mobile or respring.

Wi-Fi works through usbmuxd's network devices (`-n` on the bundled tools), which needs Wi-Fi sync turned on for this Mac: done once over USB in Finder (select the iPad, check "Show this iPad when on Wi-Fi"). It's already on for the user's iPad (`iPad-Mini.local`). The script lists devices from usbmuxd, prefers USB, picks the only iPad when other devices (like the user's iPhone) are also on Wi-Fi, and shows the connection on the confirm screen. Keep the iPad awake and unlocked during a Wi-Fi install. To target it by hand: `ideviceinfo -n -u <UDID> -k ProductVersion`.

When the iPad is plugged in you can read from it with the bundled tools, e.g. `tools/libimobiledevice/macos/ideviceinfo -s -k ProductVersion` or `ideviceinstaller list --user`. Don't install or uninstall anything without the user's go-ahead. Checks that need a person (touch feel, rotation, frame rate) go in the game's `Tests/DEVICE_CHECKLIST.md` for the user to run. Don't claim they're verified.

## Writing code for iOS 10

- iOS 10 has no SF Symbols, scene delegates, or safe-area APIs (all iOS 11+). Draw icons in code with `UIBezierPath` or bundle PNGs. For offscreen drawing, the codebase uses `UIGraphicsBeginImageContextWithOptions`.
- No runtime SVG: author in SVG or Figma, ship PNG.
- Use `NSUserDefaults` for settings and saves. Remove defaults when their setting goes away.
- Keep game rules in a Foundation-only model (`Application/Game/`), separate from SpriteKit and UIKit, so it can be unit-tested with plain `clang` on macOS (see Solitaire's `scripts/test-rules.sh`).
- Keep UIKit for chrome (menus, settings, alerts, control bars) and SpriteKit for the board.
- Respect Reduce Motion (`UIAccessibilityIsReduceMotionEnabled`), set `accessibilityLabel` on icon buttons, and keep tap targets at least 44×44pt.
- Cancel any in-progress touch interaction on rotation, backgrounding, and modal presentation.
- Match the surrounding style: compact Objective-C, sparse comments that explain why, `.clang-format` at the root.

## Performance on the A7

- 2D, 60 FPS target. Cache rendered textures (`NSCache` of `SKTexture`) and size them for how they appear on screen. Don't ship 4K art.
- Decode and render images on a background queue at launch, then create `SKTexture`s on the main thread, so the first use doesn't hitch.
- Avoid per-frame allocation, huge textures, many stacked transparent layers, heavy shaders, big particle systems, and large numbers of physics bodies. Prefer `SKAction` over hand-animating positions in `update:`.
- Asset formats: PNG for sprites and UI, JPEG only for large opaque backgrounds, CAF for short sounds, M4A for music.

## Verifying without the device

- **Compile check:** `make` with Theos, as above.
- **Simulator smoke test:** the app can be compiled directly for the simulator to check layout and rendering:

  ```sh
  SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
  xcrun clang -target arm64-apple-ios13.0-simulator -isysroot $SDK -fobjc-arc \
    -framework UIKit -framework Foundation -framework SpriteKit -framework CoreGraphics \
    Application/*.m Application/*/*.m -o /tmp/sim/<App>.app/<App>
  # copy Resources/* into /tmp/sim/<App>.app, then simctl boot / install / launch / io screenshot
  ```

  Current simulators are modern iPads (home indicator, different sizes), so this checks rendering, not the exact mini 2 layout. Rotation can't be driven headlessly here. Shut the simulator down afterwards (`xcrun simctl shutdown all`).
- **HTML tools** (like Solitaire's design playground) are opened with `file://` by the user. Playwright blocks `file:`, so serve the folder with `python3 -m http.server` to test, and keep test fixtures inside the repo's `.playwright-mcp/` (Playwright's allowed root). Delete that folder afterwards; it isn't gitignored.

## Git

- `main` is the only long-lived branch. The user is `timblazing`; remote is `github.com/timblazing/ios-games`.
- Don't commit build output other than the release `.deb`/`.ipa`/`SHA256SUMS`, test binaries, or `.playwright-mcp/`.

## Game notes

### Solitaire (`games/solitaire/`)

Draw-1 Klondike, v2.0.0. Read `README.md` and `docs/V2_SPEC.md` before changing it.

- Board layout math lives in `Application/Scenes/GameScene.m` and is mirrored in `tools/design-playground/index.html`. Change both together.
- One card design from `Resources/Cards/` (`back.png`, `<rank><suit>.png`, 250×350 PNG). Missing cards fall back to drawn ones, per card. There are no theme or card-back options by design.
- The app icon comes from `Resources/Icon/icon-1024.png` via `scripts/make-icons.sh`, which `make` runs automatically.
- No Draw 3, Vegas scoring, audio, or haptics (out of scope).
