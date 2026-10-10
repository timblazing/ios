# Solitaire for iPad mini 2

Offline Draw-1 Klondike in Objective-C, UIKit, and SpriteKit. Targets ARM64 and iOS 10.0 or later. All four orientations are supported; the board follows the device.

## Install this build

Use `packages/com.local.solitaire_2.3.0_iphoneos-arm.deb` on the jailbroken iPad. Copy it to the device and install it with Filza or run as root:

```sh
dpkg -i com.local.solitaire_2.3.0_iphoneos-arm.deb
```

The package refreshes the icon cache. If the icon is missing, run `uicache` as mobile and return to the Home screen.

`dist/Solitaire-2.3.0.ipa` contains the same app. It is ad-hoc signed for a jailbroken installation environment. An IPA installer must support that signing setup, such as an AppSync-enabled installer. It is not an Apple-provisioned IPA for a stock device. The `.deb` is the intended route for this target.

## Play

- The top row has the four foundations on the left and the waste and stock on the right, with some room above it so it's an easier reach.
- Tap the stock to draw one card. Tap its empty outline to recycle the waste.
- Tap a face-up card to send it, with any cards on top of it, to the best legal pile: its foundation first, then a tableau card, then an empty column (kings only, and only if that uncovers something). A card with nowhere to go gives a short shake.
- Or drag a face-up card or a descending, alternating-color stack onto a legal pile. Outlines mark legal destinations while dragging.
- Exposed face-down tableau cards flip automatically.
- Undo restores the previous move, including a draw, recycle, or automatic flip. The last 200 actions are available during the current session.
- The controls bar sits at the bottom: time and moves on the left, then Undo (back arrow), New game (circular arrow), and Settings (gear).
- Once every tableau card is face up, a gold Auto Win button appears in the controls bar. It plays the rest out to the foundations, drawing through the stock as needed. Any interruption (Undo, New game, Settings, rotation, backgrounding) stops it; tap it again to resume.
- New game replaces the board after confirmation. A completed game locks board interaction and celebrates: confetti over the whole screen, "Congrats Reagan!" in rainbow WordArt with clip-art stars, the kings and queens dancing in a line, and the time and moves above the bar. Reduce Motion keeps the message and the line of cards but drops the confetti and dancing.

The board, move count, and elapsed time save locally. Undo history does not survive a relaunch. The timer pauses in the background. Settings shows games played, wins, and current win streak. Replacing an unfinished game breaks the streak.

## Card art

The app uses one card design from `Resources/Cards/`: `back.png` plus 52 faces named `<rank><suit>.png`, with ranks `A 2 3 4 5 6 7 8 9 10 J Q K` and suits `S H D C` (for example `AS.png`, `10H.png`, `QC.png`). Export PNGs at 250×350 px (exactly 5:7). The app clips rounded corners and adds the shadow, so the art can be a plain rectangle.

Any missing or unreadable card falls back to the built-in drawn card (rank text and suit symbol, or the slate lattice back). An empty folder gives the v1 look, so a partial set works while you design. Missing filenames are logged once at launch. All textures are rendered on a background queue at launch for both orientations, so the first flip doesn't hitch.

Candidate designs are in `docs/card-designs/sets/<set>/`: one SVG and one 250×350 PNG per card, with the same names. `scripts/make-card-svgs.py` builds them (it overwrites that folder, so copy a set elsewhere before reworking it by hand); each set is a palette plus a court style, with suit shapes matching the app icon and court figures from CC0 art in `docs/card-designs/courts/`. To compare sets on a simulated board, serve the game folder (`python3 -m http.server 8765`) and open `http://127.0.0.1:8765/tools/design-playground/`. The app ships the `traditional` set: red and black faces, a red back, and a green-felt icon to match the board. To switch, copy another set's card PNGs into `Resources/Cards/` and its `icon-1024.png` into `Resources/Icon/`.

Only the top ~24% of a face-up card shows in a landscape tableau column (32% in portrait), and as little as ~14% when a long column compresses. The generated sets keep the rank and suit side by side in the top 62 px and start pips and court art below that, so a compressed column reads cleanly.

## App icon

Put a 1024×1024, fully opaque, square PNG at `Resources/Icon/icon-1024.png`. `scripts/make-card-svgs.py` writes one per set (the set's back and A♠ fanned on the board color); the previous icon is kept at `docs/card-designs/previous-icon-1024.png`. Don't round the corners; iOS masks the icon. `make` runs `scripts/make-icons.sh`, which uses macOS `sips` to write the seven bundle sizes (`Icon-29.png` through `Icon-83.5@2x.png`). Without the master, or without `sips`, the existing icons are kept. The home screen uses the 152 px icon, so design for that size.

iOS may keep showing the old icon after an update. Run `uicache` as mobile or respring.

## Design playground

`tools/design-playground/index.html` previews card art and the app icon before building. Open it directly (`open tools/design-playground/index.html`); it needs no server and nothing leaves the browser.

- Cards: load the `Resources/Cards/` folder to validate filenames, ratio, and size, see the full deck, a dealt board in landscape or portrait with the bottom controls bar, and worst-case overlap stress views. Missing cards preview as the app's fallback. Zoom shows points, device pixels, or approximate physical size.
- App icon: load `icon-1024.png` to check size and transparency, see the 152/80/58 px sizes, an iOS 10 home screen mock with dark, light, or custom wallpaper, and the v1 icon side by side.

The board math mirrors `Application/Scenes/GameScene.m`. Update both together.

## Build

On macOS, install Xcode and Theos (`theos.dev/docs/installation-macos`). The Theos installer adds the iPhoneOS 16.5 SDK, which this project builds against. Then:

```sh
export THEOS=~/theos
make package FINALPACKAGE=1 -j4
scripts/package-ipa.sh
```

The SDK only supplies headers and link stubs; the deployment target is what keeps the app on iOS 10.0 (`TARGET = iphone:clang:16.5:10.0`). The iPhoneOS 10.3 SDK can't be used with current Xcode: its link stubs list arm64 and x86_64 under one platform, and the current linker treats them as simulator libraries. With a 10.0 deployment target, clang warns about unguarded iOS 11+ API use, so new-API mistakes still surface at compile time.

The build disables C++ and Objective-C exception handling; the app doesn't use exceptions. When changing toolchains, check the binary's deployment command with `vtool -show-build`. It should be `LC_VERSION_MIN_IPHONEOS` with version 10.0.

## Code

- `Application/Game/` contains the Foundation-only model, deck, validation, snapshots, undo, and statistics. Piles are ordered card arrays; their rules live in `SolitaireGame`.
- `Application/Scenes/GameScene` handles layout, picking, dragging, selection, and motion.
- `Application/Nodes/` renders cards and pile outlines.
- `Application/UI/` contains settings and the bottom controls bar, whose icons are drawn in code.
- `GameViewController` owns the scene, timer display, lifecycle handling, and the win celebration (`UI/CelebrationView`).

No networking, accounts, ads, analytics, achievements, or multiplayer. Audio, haptics, Draw 3, and Vegas scoring are out of scope. Sound preference is initialized to off for future use; there are no sound effects or sound controls yet.

## Tests

On macOS with command-line developer tools:

```sh
scripts/test-rules.sh
```

On Linux, the same script needs GNUstep Base built against libobjc2 with the modern Objective-C runtime and ARC. A distribution's legacy GNUstep runtime is insufficient. Tests compile the actual app model without SpriteKit or UIKit. They cover rule boundaries, recycling order, undo, persistence, statistics, victory, auto-win, and 2,400 randomized play steps with board invariants.

See `Tests/DEVICE_CHECKLIST.md` for the remaining iPad checks. Install, rotation, and A7 frame rate still need checking on the iPad.
