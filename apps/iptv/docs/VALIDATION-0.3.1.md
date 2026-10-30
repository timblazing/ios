# TV 0.3.1 validation — 2026-10-29

Prepared build 4; **not installed on the physical iPad**. The 0.3.0 physical picture/audio result remains recorded separately in [VALIDATION-0.3.0.md](VALIDATION-0.3.0.md).

## Build and checks

- Theos arm64 IPA/DEB packaged without compiler or API-availability warnings. Theos's existing `-multiply_defined is obsolete` warning remains.
- `vtool`: `LC_VERSION_MIN_IPHONEOS`, minimum version 10.0.
- Foundation guide tests pass. New configuration tests pass for missing-file preservation, normalization, omitted settings, and atomic rejection of invalid URLs/types/credentials.
- Gateway Python: 8 tests pass. USB adapter Python: 5 tests pass, including synthetic guide→redirect→playlist→segment HTTP behavior.
- Public IPA/DEB identity, version 0.3.1/build 4, private-profile exclusions, macOS-metadata exclusions, ZIP integrity and all release checksums pass. No actual server configuration is bundled.
- Retained relay sources were unchanged; their earlier 0.3.0 regression results are historical evidence, not a new physical acceptance pass.

## Native simulator checks

Used T3 `device_list` / `device_open`, the returned device-bound `agent-device` command, and `device_screenshot`: iPad mini (A17 Pro), iOS 18.3. Checked portrait and landscape, NFL→NBA→NCAAF changes, selected-state labels, and scrolling to the last network tiles. No refresh/settings button remains. The floating capsule overlays the scrolling collection; the last cards can clear it at the end of the scroll range.

A synthetic 640×360/30 HLS video with an eight-second delayed playlist supplied an unambiguous first picture. The final player run logged:

- 16:46:09.509: controls visible, picture not yet available.
- 16:46:18.514: first picture; controls visible and hide timer started.
- 16:46:21.016: controls hidden (**2.502 seconds** after first picture).
- 16:46:21.513: playback advancing, 640×360, video layer ready.

The earlier run independently showed 2.501 seconds after first picture. The saved player image shows a single `Panthers @ Packers` title, picture, pause and top-right AirPlay indicator. The simulator has no usable wireless output route/system volume slider, so functional AirPlay/volume routing is not verified. The synthetic clip ends normally and is treated as feed unavailable by the live player; it is a timing fixture, not a live-channel/endurance test.

## Evidence

Public guide metadata only; player uses generated test video. No settings, private endpoint, token or live guide fixture is committed.

- [Guide portrait and glass capsule](validation-0.3.1/guide-portrait.png)
- [Guide landscape, final rows reachable](validation-0.3.1/guide-landscape.png)
- [Loading controls and single title](validation-0.3.1/player-loading.png)
- [First picture with revised header](validation-0.3.1/player-playing.png)

## Still pending

Owner-approved installation of 0.3.1; physical first-picture/timer behavior, glass appearance/scroll performance on the A7, startup, 720p60/1080p60 smoothness, pause/resume/back, AirPlay/volume, rotation, 2+ minute background recovery and endurance. Reduce Transparency/VoiceOver behavior is implemented but not device-accepted. No physical 0.3.0 pass automatically validates changed 0.3.1 behavior.

The legacy relay remains compiled. Temporary test services were stopped; see [HANDOFF.md](HANDOFF.md) for the iPad gateway restoration item and private local backup location.
