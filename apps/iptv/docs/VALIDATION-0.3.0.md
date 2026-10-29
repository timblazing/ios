# TV 0.3.0 validation — October 29, 2026

## Automated checks

- Clean Theos arm64 package build: no compiler/API-availability warnings. Theos still emits its documented `-multiply_defined is obsolete` linker warning.
- `vtool`: `LC_VERSION_MIN_IPHONEOS`, version **10.0**.
- `scripts/test-guide.sh`: plain macOS clang, Foundation only, `-Wall -Wextra -Werror`; scrubbed live `/guide.json` fixture, league/game/feed ordering, dates, malformed structure, unsafe streams and optional metadata/EPG sanitation pass.
- `scripts/test-stream.sh`: retained M3U/relay/segmenter/HEVC-rejection regressions pass; ffprobe checked 27 segments.
- Gateway Python suite: 7 tests pass.
- Live gateway `/health`: 38 channels, `errors: {}`.
- Release IPA/DEB checksums verified. No private configuration is bundled.

## Simulator

Arm64 iPad mini (A17 Pro), iOS 18.3. Built using `scripts/build-simulator.sh`; installed/launched/driven with the Device panel tools. This checks modern AVPlayer HLS compatibility and UIKit rendering, not iOS 10 runtime behavior, A7 decode performance, physical touch or AirPlay.

The live gateway populated all three tabs (NFL 14 games, NBA 3, NCAAF 5 at the snapshot). Team logos loaded through `/logo`; sampled network logos returned `404 no logo` and correctly showed abbreviation fallbacks. Network tiles displayed real gateway now/next data and progress. The current Dispatcharr XMLTV still includes generic program names.

Portrait uses two columns; landscape uses three. Compared screenshots with `docs/design/browser-mock.html` at 768×1024 and 1024×768: palette, 20-point margins, 12-point gutters, 46-point team rows, card sizes, title hierarchy and player chrome follow the mock. The modern mini has a taller aspect ratio/home indicator; the mock's data order/time is a separate snapshot. Native tabs use NFL/NBA/NCAAF order from NEXT.md. The release keeps the original launch resources; a simulator-only plist dictionary avoids modern compatibility-window coordinate offsets.

Pre-game taps showed local start time without opening the player. NFL Network played real video using the gateway's original `?output_format=hls` endpoint. Simulator diagnostics confirmed advancing 1280×720 video and `AVPlayerLayer.readyForDisplay = YES`. Controls hid, Pause changed to Play, and GO LIVE restored playback. Returning after 75 seconds, and again after 121 seconds in the background, rebuilt playback and again reported advancing 1280×720 video with the layer ready. The latter run left at 16:30:32 UTC and returned at 16:32:33 UTC.

A temporary local guide (kept outside the repo) supplied two synthetic live games, a pre-game, a deliberately missing primary URL and one real NFL Network backup. The player displayed “Trying backup feed…” and then real video. Left swipes updated game title/toast; swiping to the pre-game displayed its start time and stopped streaming. A forced guide 503 preserved the last valid cards and showed a connection message; removing the failure produced an unchanged 304, cleared the message and retained the cards (fixture-server log verified both status codes). Tests used one player/stream at a time.

## Evidence

The checked-in guide images contain only public game/network metadata. Player evidence is a short still from the playback test. No settings screenshot, stream URL, session token or live fixture is committed.

- [Guide portrait](validation-0.3.0/guide-portrait.png)
- [Guide landscape](validation-0.3.0/guide-landscape.png)
- [Network tiles](validation-0.3.0/networks-landscape.png)
- [Direct HLS video](validation-0.3.0/player-live.png)

## Physical acceptance

No physical iPad install or test. All human checks remain unchecked in `Tests/DEVICE_CHECKLIST.md`, including iOS 10 HLS, smooth 720p60/1080p60, audio/routes, touch, rotation, memory/endurance and background recovery. The legacy relay remains compiled and available in source until that acceptance passes.
