# TV

Native live TV guide and player for the iPad mini 2 on iOS 10.3.3, built with Objective-C/UIKit and Theos.

**Prepared build:** [IPTV-0.3.2.ipa](dist/IPTV-0.3.2.ipa), [Debian package](packages/com.local.iptv_0.3.2_iphoneos-arm.deb), [checksums](dist/SHA256SUMS). Adds automatic home-first gateway fallback. Physical iPad currently has 0.3.1 / build 4; 0.3.2 installation and acceptance are pending.

**Resume here:** [backlog](docs/BACKLOG.md), [handoff](docs/HANDOFF.md), [next steps](docs/NEXT.md).

## Use

The app is privately preconfigured; there is no settings screen or manual refresh. Existing device defaults remain supported. The gateway supplies stream addresses; Dispatcharr configuration remains private.

Choose NFL, NBA or NCAAF in the centered floating bottom capsule. It uses an iOS 10-compatible glass treatment (blur, subtle rim/highlight and translucent selection) with a solid Reduce Transparency fallback. Guide content scrolls behind it; the last cards can scroll clear of the capsule. Game cards show start time or status, teams, records and scores. Network tiles show current/next EPG with progress when available. The guide refreshes every 30 seconds while visible using ETag, retaining the last valid data during outages. It tries the primary home gateway first, then the optional USB bridge when the primary request fails, times out or returns an invalid guide. Every refresh retries home. Logos and stream addresses follow the selected guide route; cached validators are scoped to that route. Logos come through the gateway at 96 pixels, decode off the main thread, and use an 8 MB NSCache; unavailable logos show abbreviation badges.

Tap a game to play, or a network tile to watch that channel. Pre-game cards show the start time and request no stream. The player shows one centered matchup or channel title. Controls stay visible while loading and hide 2.5 seconds after a picture is ready and playback is running. Tap to toggle controls after playback starts. Swipe between games in the selected league. Pause/resume and volume sit at the bottom; AirPlay is top right (dim when no wireless route is available). LIVE/GO LIVE is removed. Failed feeds advance through the game's backups (including a 20-second no-progress timeout). Backgrounding releases playback; returning creates a new item from the original endpoint, avoiding expired HLS tokens.

## Private configuration

Before installing, preserve/provision the app's device defaults (`gateway.baseURL`, optional `gateway.fallbackBaseURL`, `server.baseURL`) or supply `Library/Preferences/com.local.iptv.configuration.plist` under the app's home directory. On the unsandboxed jailbroken iPad this is normally under `/var/mobile`; confirm the home directory before writing. In the simulator use the app data container. A valid profile applies those optional HTTP(S) base-URL keys at launch; omitted keys preserve stored settings. Invalid profiles are rejected atomically. No credentials, query strings or fragments in these base URLs. Set `gateway.baseURL` to the private home gateway and `gateway.fallbackBaseURL` to the loopback USB bridge. Omitted keys preserve stored values; an empty fallback string removes that setting. Each candidate has a four-second request timeout and six-second overall resource timeout. The USB bridge must be running to work away from home; this feature does not start forwarding or provide independent remote access.

Keep the real profile/addresses **on the device or outside the checkout**. Never put it in `Resources`, an IPA/DEB, test fixture or Git. Existing stored configuration is used when no profile exists; an unconfigured install shows a neutral message instead of a settings form. Public build/package guards reject private profile filenames. For temporary offsite acceptance, see [USB bridge tooling](../../tools/tv-usb/README.md) and the [handoff cleanup item](docs/HANDOFF.md#shutdown--private-state).

## Stream compatibility

The player uses AVPlayerLayer with Dispatcharr's `?output_format=hls` stream directly. The A7 needs H.264/AAC; HEVC requires a server-side H.264 profile. See [stream findings](docs/STREAMS.md).

The Foundation-only legacy relay, segmenter, local server and M3U parser remain in the source and build until physical-device HLS acceptance. They are not used by the new guide/player. Existing 0.2.0 packages remain available for rollback.

## Build and test

```sh
export THEOS=~/theos
make package FINALPACKAGE=1 -j4
vtool -show-build .theos/_/Applications/IPTV.app/IPTV
scripts/package-ipa.sh
scripts/test-configuration.sh         # private-profile validation/preservation
scripts/test-gateway.sh               # real HTTP fallback/recovery, validators, timeout/cancellation
scripts/test-guide.sh                 # Foundation model and scrubbed live fixture
scripts/test-stream.sh                # retained relay regression tests; ffmpeg required
python3 -m unittest discover -s gateway/tests
scripts/build-simulator.sh            # /tmp/tv-simulator/IPTV.app, arm64 simulator
```

In T3 Code, follow the [Device panel workflow](../../AGENTS.md#verifying-without-the-device): `device_list`, then `device_open` with the selected host/device IDs, then the returned device-bound `agent-device` command for launches and interaction, and `device_screenshot` for inspection. Command-line builds and installs remain allowed. Provision the gateway privately before launching. The simulator-only launch-screen dictionary avoids modern iPad compatibility-window coordinates; release resources are unchanged. Shut down only the simulator started for this task once the owner is done interacting. For deterministic failure/304 testing, `scripts/serve-guide-fixture.py <fixture> --fail-flag /tmp/tv-guide-fail` serves on loopback port 19493: create the flag for 503, remove it for recovery. Never commit a private live fixture.

## Code and validation

- `Application/Guide/`: Foundation-only typed guide parser; malformed responses cannot replace the last good guide.
- `Application/UI/`: native collection guide and custom AVPlayerLayer player.
- `Application/Stream/`: retained legacy relay and model.
- [Gateway API](gateway/README.md), [implementation plan](docs/NEXT.md), [design mock](docs/design/browser-mock.html).
- [0.3.0 validation](docs/VALIDATION-0.3.0.md) records simulator evidence and its limits.
- [0.3.1 validation](docs/VALIDATION-0.3.1.md) covers the earlier build and simulator evidence.
- [0.3.2 validation](docs/VALIDATION-0.3.2.md) covers automatic gateway selection and release checks.
- [Device checklist](Tests/DEVICE_CHECKLIST.md) preserves the 0.3.0 guide/RedZone picture/audio passes; 0.3.1 installation is verified; 0.3.2 installation and remaining functional acceptance are pending.

Dispatcharr authentication and provider credentials are not handled by this app. Keep the gateway and Dispatcharr on a trusted private network.
