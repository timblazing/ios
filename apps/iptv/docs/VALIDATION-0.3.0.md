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

The owner-approved USB install completed on the physical iPad mini 2 / iOS 10.3.3; a subsequent installed-app query reports TV 0.3.0. First-launch settings have been observed; playback acceptance is blocked on remote network access. All human checks remain unchecked in `Tests/DEVICE_CHECKLIST.md`, including iOS 10 HLS, smooth 720p60/1080p60, audio/routes, touch, rotation, memory/endurance and background recovery. The legacy relay remains compiled and available in source until that acceptance passes.

Read-only acceptance preflight on 2026-10-29 found zero USB/Wi-Fi devices through usbmuxd; T3 Device panel discovery exposed simulators only. No install or physical test followed. See the device checklist acceptance log for the next step.

The owner then reported that the iPad battery was depleted and requested stopping device work until it is charged and rejailbroken. No physical playback results were collected. The owner subsequently resumed: read-only USB/Wi-Fi queries confirmed iPad4,5 / iOS 10.3.3, with TV 0.2.0 installed. The owner then approved installing 0.3.0 over USB. The release IPA SHA256 matched `dist/SHA256SUMS`, installation reported `Install: Complete`, and `ideviceinstaller list` returned `CFBundleShortVersionString` **0.3.0** for `com.local.iptv`. On first launch, the owner reported a blank Gateway URL and a retained Dispatcharr URL. The iPad and Mac are away from the home LAN; guide/playback checks remain pending until secure remote access is configured. No video stream was opened for physical acceptance.

## Network-logo follow-up — 2026-10-29

Reproduced upstream 404s for ESPN, NFL Network and CBS Sports Network. The source repository owner was misspelled (`tv-logos` instead of `tv-logo`). All 18 configured filenames exist in the corrected public repository. Requests through raygun's running `/logo` endpoint with the corrected URLs returned HTTP 200, `image/png`, and 96×96 PNGs for all 18. The gateway Python suite passes all 7 tests, including the corrected NFL Network URL assertion. No video streams were opened.

The gateway source fix is prepared for review; the live gateway has not been redeployed, and its generated guide still needs verification after deployment. This is gateway endpoint evidence, not physical-device logo/rendering acceptance. No app version or package changed.

## USB bridge and guide-group recovery — 2026-10-29

The owner approved a Mac/USB bridge for offsite testing and closed TV before provisioning. Existing SSH key authentication to the physical iPad succeeded. A loopback-only Mac adapter, USB reverse SSH forward and SSH/Tailscale forwards now connect the iPad to a temporary gateway candidate on raygun. Private configuration and the original preferences backup are outside Git. Only the gateway preference was changed; the Dispatcharr preference was preserved. No app rebuild or reinstall was needed.

Reproduced a new source mismatch: production `/guide.json` had zero games/tiles in every league while its health showed 41 channels. Dispatcharr group labels had provider prefixes/suffixes (`US| NFL PPV`, etc.), but grouping required exact NFL/NBA/NCAAF equality. Match league names as whole tokens instead; the regression test includes decorated groups and rejects a WNBA false match. All 8 gateway tests pass. A candidate container using the corrected source runs on raygun loopback only; production was not redeployed.

A guide request made **from the physical iPad** through the bridge returned NFL 14 games / 3 tiles, NBA 3 / 1 and NCAAF 1 / 18 at the snapshot. All emitted stream URLs used iPad loopback. The adapter's 5 tests pass, including a synthetic HTTP redirect→playlist→segment round trip and conditional-guide responses. This does not prove live HLS playback or UIKit rendering. Owner confirmation of the visible guide is next; no video stream has been opened in this acceptance run.

The bridge forwards HLS without transcoding or TS segmentation. Later startup/throughput results must be labeled as using this USB/Mac/tailnet path. Keep the legacy relay until physical acceptance is complete. See `../../../tools/tv-usb/README.md` for task-owned process cleanup and preference restoration.

### First owner-reported guide and HLS result

After reopening TV with the private bridge configured, the owner confirmed that the guide was populated and reported successful NFL RedZone playback on the physical iPad mini 2 / iOS 10.3.3. This establishes visible guide content and a working HLS picture through the USB/Mac/tailnet adapter. Audio synchronization, startup time, codec/resolution/frame rate, sustained performance, controls, background recovery and rotation have not yet been verified. No second acceptance stream was started by the agent. Keep the legacy relay while the remaining acceptance is incomplete.
