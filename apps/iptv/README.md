# TV

Native live TV guide and player for the iPad mini 2 on iOS 10.3.3, built with Objective-C/UIKit and Theos.

**Release:** [IPTV-0.3.0.ipa](dist/IPTV-0.3.0.ipa), [Debian package](packages/com.local.iptv_0.3.0_iphoneos-arm.deb), [checksums](dist/SHA256SUMS).

## Use

Enter the gateway base URL in **Server settings**, alongside the Dispatcharr base URL. Both stay in device defaults. The gateway supplies the stream addresses; the Dispatcharr setting is retained for server configuration and the legacy path.

Choose NFL, NBA or NCAAF. Game cards show start time or status, teams, records and scores. Network tiles show current/next EPG with progress when available. The guide refreshes every 30 seconds while visible using ETag, retaining the last valid data during outages. Logos come through the gateway at 96 pixels, decode off the main thread, and use an 8 MB NSCache; unavailable logos show abbreviation badges.

Tap a game to play, or a network tile to watch that channel. Pre-game cards show the start time and request no stream. In the player, tap to show controls; they hide after three seconds. Swipe between games in the selected league. Pause and **GO LIVE** control playback; system volume/AirPlay controls sit at the bottom. Failed feeds advance through the game's backups (including a 20-second no-progress timeout). Backgrounding releases playback; returning creates a new item from the original endpoint, avoiding expired HLS tokens.

## Stream compatibility

The player uses AVPlayerLayer with Dispatcharr's `?output_format=hls` stream directly. The A7 needs H.264/AAC; HEVC requires a server-side H.264 profile. See [stream findings](docs/STREAMS.md).

The Foundation-only legacy relay, segmenter, local server and M3U parser remain in the source and build until physical-device HLS acceptance. They are not used by the new guide/player. Existing 0.2.0 packages remain available for rollback.

## Build and test

```sh
export THEOS=~/theos
make package FINALPACKAGE=1 -j4
vtool -show-build .theos/_/Applications/IPTV.app/IPTV
scripts/package-ipa.sh
scripts/test-guide.sh                 # Foundation model and scrubbed live fixture
scripts/test-stream.sh                # retained relay regression tests; ffmpeg required
python3 -m unittest discover -s gateway/tests
scripts/build-simulator.sh            # /tmp/tv-simulator/IPTV.app, arm64 simulator
```

In T3 Code, follow the [Device panel workflow](../../AGENTS.md#verifying-without-the-device): `device_list`, then `device_open` with the selected host/device IDs, then the returned device-bound `agent-device` command for launches and interaction, and `device_screenshot` for inspection. Command-line builds and installs remain allowed. Configure the live gateway through its settings UI. The simulator-only launch-screen dictionary avoids modern iPad compatibility-window coordinates; release resources are unchanged. Shut down only the simulator started for this task once the owner is done interacting. For deterministic failure/304 testing, `scripts/serve-guide-fixture.py <fixture> --fail-flag /tmp/tv-guide-fail` serves on loopback port 19493: create the flag for 503, remove it for recovery. Never commit a private live fixture.

## Code and validation

- `Application/Guide/`: Foundation-only typed guide parser; malformed responses cannot replace the last good guide.
- `Application/UI/`: native collection guide and custom AVPlayerLayer player.
- `Application/Stream/`: retained legacy relay and model.
- [Gateway API](gateway/README.md), [implementation plan](docs/NEXT.md), [design mock](docs/design/browser-mock.html).
- [0.3.0 validation](docs/VALIDATION-0.3.0.md) records simulator evidence and its limits.
- [Device checklist](Tests/DEVICE_CHECKLIST.md) remains unchecked for this release. No iPad install was performed.

Dispatcharr authentication and provider credentials are not handled by this app. Keep the gateway and Dispatcharr on a trusted private network.
