# TV 0.3.0 device checklist

Run on the iPad mini 2 / iOS 10.3.3 with gateway and Dispatcharr reachable. These checks require a person; simulator evidence is in `docs/VALIDATION-0.3.0.md`. No 0.3.0 device checks have been marked complete. Historical 0.1.0 relay playback passed on 720p channels; that is not direct-HLS acceptance.

## Acceptance log — 2026-10-29

- **Pending:** read-only usbmuxd discovery returned zero USB/Wi-Fi connections. T3 `device_list` listed simulators only; no physical iPad was exposed.
- Initial preflight performed no installation or physical playback test. All functional acceptance items below remain pending; retain the legacy relay.
- The owner initially paused acceptance to charge and rejailbreak the iPad, then resumed. Read-only discovery now confirms iPad mini 2 (`iPad4,5`), iOS 10.3.3, reachable over USB and Wi-Fi; TV **0.2.0** was installed at discovery. The owner approved installing 0.3.0 over USB.
- **Pass — installation:** verified the release IPA SHA256, installed over USB (`Install: Complete`), then queried `com.local.iptv`: `CFBundleShortVersionString` is **0.3.0**. No physical playback checks have run.
- **Observed — first launch/settings:** owner opened TV; Gateway URL was blank and the previous Dispatcharr URL was retained. Guide and playback acceptance remain pending.
- **Pass — bridge transport:** owner approved a temporary USB/Mac bridge. Existing SSH key authentication succeeded. A loopback-only reverse SSH forward and Mac guide/HLS adapter reach an isolated gateway candidate on raygun through Tailscale. Fetching the guide from the physical iPad returned NFL 14 games / 3 tiles, NBA 3 / 1, NCAAF 1 / 18 at the snapshot; all stream URLs use iPad loopback. This is transport evidence, not UIKit rendering or playback acceptance.
- **Configured:** while TV was closed, backed up its preferences outside the repo and set only `gateway.baseURL` to the bridge. Preserved the existing Dispatcharr setting. No reinstall or public endpoint. Owner to reopen TV and confirm visible guide content; HLS picture/audio and all remaining functional checks are pending.
- Keep USB connected and the Mac awake during testing; see `tools/tv-usb/README.md` at the repository root for bridge cleanup/restoration.
- Run one interaction at a time and record pass/fail/pending plus actual observations: HLS picture/audio and tap-to-picture time first, then controls, 2+ minute background recovery, rotation and sustained 720p60. Test one stream at a time. Record remaining checks without treating simulator results as physical passes.

## Guide and interaction

- [ ] Enter gateway and Dispatcharr URLs; relaunch and verify settings persist.
- [ ] NFL / NBA / NCAAF tabs, refresh and server controls are comfortable to tap.
- [ ] Three columns in landscape and two in portrait; rotate while scrolling without clipped cards or stuck touches.
- [ ] Team/network logos remain smooth while scrolling; missing logos show abbreviations.
- [ ] Scores, status and EPG update over several polling cycles without flicker or scroll jumps.
- [ ] Disconnect/reconnect Wi-Fi: last good guide remains, errors clear when the gateway recovers.
- [ ] A wrong gateway URL shows an error; correcting it reloads the guide.
- [ ] Tapping a pre-game card shows local start time without opening video.
- [ ] VoiceOver reads card/team/status details and labels all controls; Reduce Motion removes control fades.

## Direct Dispatcharr HLS (no relay)

- [ ] A channel's original `?output_format=hls` endpoint plays in the app on iOS 10.3.3. This gates retiring the legacy relay.
- [ ] Startup on a 24/7 channel is acceptable (aim under 3 s; record actual tap-to-picture time).
- [ ] 720p60 plays smoothly, with audible synchronized audio and no dropped frames.
- [ ] A 1080p60 H.264 channel plays smoothly for several minutes.
- [ ] HEVC-only feeds fail clearly or use a configured server-side H.264 profile; no indefinite spinner.
- [ ] Tap toggles controls; controls hide after 3 s; back chevron reliably closes playback.
- [ ] Pause, resume and GO LIVE return to the live edge.
- [ ] System volume slider and AirPlay work on this device.
- [ ] Swipe left/right changes games and shows the correct toast; pre-game targets show start time without streaming.
- [ ] A failed primary feed switches to a backup; all failed feeds show an inline error with a usable Back control.
- [ ] Closing and reopening channels works ten times without overlapping provider streams.
- [ ] Rotation during playback preserves video, controls and touch handling.
- [ ] Home/lock stops video; after 2+ minutes returning re-requests the original endpoint and resumes.
- [ ] Silent switch/audio interruptions and route changes behave sensibly.
- [ ] 30 minutes without memory termination, stutter or increasing live delay.

Test one stream at a time; the provider allows only two connections. Ask before installing on the physical iPad.
