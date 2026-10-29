# TV 0.3.0 device checklist

Run on the iPad mini 2 / iOS 10.3.3 with gateway and Dispatcharr reachable. These checks require a person; simulator evidence is in `docs/VALIDATION-0.3.0.md`. No 0.3.0 device checks have been marked complete. Historical 0.1.0 relay playback passed on 720p channels; that is not direct-HLS acceptance.

## Acceptance log — 2026-10-29

- **Pending:** read-only usbmuxd discovery returned zero USB/Wi-Fi connections. T3 `device_list` listed simulators only; no physical iPad was exposed.
- No installation or physical playback test was performed. All acceptance items below remain pending; retain the legacy relay.
- **Paused by owner:** the iPad battery is depleted; it must charge and be rejailbroken. Wait for the owner to resume. Then connect and unlock it, verify iPad mini 2 / iOS 10.3.3 and the installed TV version, and ask before installing 0.3.0.
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
