# Next session: native UIKit build of the guide and player

The design is `docs/design/browser-mock.html` (open it with `file://`; press G or P to switch views, T to change the time, and use arrow keys to switch channels). The data comes from the gateway (`gateway/README.md`), and streams from Dispatcharr HLS (`docs/STREAMS.md`).

## Plan

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

## Constraints

- iOS 10 APIs only, Objective-C, `-Wunguarded-availability-new` clean (see `AGENTS.md`).
- 44 pt tap targets, `accessibilityLabel` on icon buttons, respect Reduce Motion.
- Never commit server addresses, stream UUIDs or provider URLs.
