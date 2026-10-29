# Native guide and player: 0.3.0

The design is `docs/design/browser-mock.html` (open it with `file://`; press G or P to switch views, T to change the time, and use arrow keys to switch channels). The data comes from the gateway (`gateway/README.md`), and streams from Dispatcharr HLS (`docs/STREAMS.md`).

## Status

Implemented in 0.3.0: gateway settings, Foundation model/tests, native collection guide with ETag polling and cached logos, direct HLS player, backup feeds, swipe controls and pre-game handling. See `VALIDATION-0.3.0.md` for proof and remaining limits.

Next: run the unchecked physical-device checklist. Keep the relay code until direct HLS plays on the mini 2, then remove the relay/M3U implementation in a separate change. The network-logo 404s were traced to a repository-owner typo and fixed in the gateway source; all 18 corrected URLs passed through the running gateway as 96×96 PNGs. Deployment and physical rendering remain pending; the app keeps abbreviation fallbacks. See `../gateway/README.md`.

## Implemented plan

1. **Settings.** Store a gateway URL (`gateway.baseURL`) next to `server.baseURL`. Drop the M3U parsing path once the guide works.
2. **Model.** Add `IPTVGuide` (Foundation only, in `Application/Stream/` or a new `Application/Guide/`). It parses `/guide.json` into leagues → games → channels. Unit-test it with `clang` on the Mac, like Solitaire's `test-rules.sh`, using a fixture JSON with `192.0.2.x` and zero UUIDs.
3. **Guide screen.**
   - Left-aligned NFL / NBA / NCAAF segmented tabs, plus refresh and server icons on the right. No title or date.
   - Game cards in a 3-column `UICollectionView` (2 in portrait). Each card has the time/status, the network, and two 46 pt team rows (logo, name, record, score). No channel numbers and no colored top border.
   - Network tiles below the cards, with the logo, name and an EPG now/next progress bar.
   - Poll `/guide.json` with `If-None-Match` every 30 s while visible.
4. **Logos.** Load them from the gateway `/logo?...&s=96` on a background queue, decode off the main thread, and keep them in an `NSCache` of `UIImage`. Fall back to a team-color badge with the abbreviation.
5. **Player.**
   - Use `AVPlayerLayer` playing the channel's `stream` URL directly.
   - Top bar: ghost back chevron, centered title plus network, LIVE pill top right (gray "GO LIVE" when behind; tapping it seeks to the live edge).
   - Bottom bar: pause, volume, AirPlay (`MPVolumeView`).
   - Controls auto-hide after 3 s. Swipe left or right switches to the next game in the tab and shows a toast.
   - If a feed fails, try the game's next channel (backup feed).
   - On return from background, re-request the original URL, because the HLS token expires after about 60 s.
6. **Pre-game.** Tapping a `pre` game shows its start time and plays nothing (placeholder clips error out).
7. **Retire the relay** once `Tests/DEVICE_CHECKLIST.md` confirms Dispatcharr HLS plays on the iPad.

## Working mode

The owner has resumed physical acceptance after charging and rejailbreaking. Read-only discovery confirms iPad4,5 / iOS 10.3.3 over USB and Wi-Fi, with TV 0.2.0 installed. Ask before installing 0.3.0, then use `Tests/DEVICE_CHECKLIST.md` one interaction at a time. Keep the legacy relay while acceptance is incomplete.

Verify each step yourself, without the device:
- `make package FINALPACKAGE=1 -j4` builds warning-free, and `vtool` shows iOS 10.0.
- Model tests run with plain `clang` against a fixture of `/guide.json` (save a live copy with `curl` and scrub its addresses).
- In the simulator smoke test (see `AGENTS.md`), the guide renders from the live gateway and the player plays a real `?output_format=hls` URL. A modern simulator's AVPlayer is a fair proxy for the HLS format, but not for A7 decode speed. Take screenshots, compare them with the mock, and shut the simulator down afterwards.
- `ssh raygun 'curl -s localhost:9292/health'` reports no errors.

Add anything that needs a person (touch feel, frame rate, rotation) to `Tests/DEVICE_CHECKLIST.md`. Don't mark those items done. Ask before installing on the iPad.

## Constraints

- iOS 10 APIs only, Objective-C, `-Wunguarded-availability-new` clean (see `AGENTS.md`).
- 44 pt tap targets, `accessibilityLabel` on icon buttons, respect Reduce Motion.
- Never commit server addresses, stream UUIDs or provider URLs.
