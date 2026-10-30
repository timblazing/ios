# TV physical-device checklist

Run on the iPad mini 2 / iOS 10.3.3 with gateway and Dispatcharr reachable. These checks require a person; simulator evidence is in `docs/VALIDATION-0.3.0.md`. The owner-reported 0.3.0 picture/audio checks below are historical; 0.3.1 physical checks remain pending. Historical 0.1.0 relay playback passed on 720p channels; that is not direct-HLS acceptance.

## Current 0.3.2 acceptance summary — short home checks complete

Owner accepts the current home experience on installed 0.3.2 / build 5. Reported passes:

- Home guide/cards/logos; responsive league tabs and scrolling; final cards reachable; future-game start-time message.
- Sampled NBA, regular NFL and NCAAF picture/audio; approximately one minute of smooth NFL playback.
- Controls remain visible until picture, hide after about 2.5 seconds, tap restores them, and Back returns to the guide.
- Short pause/resume, bottom volume slider and functional AirPlay.
- Home/background recovery after more than two minutes; portrait/landscape playback with usable controls.
- Three sequential NFL open/close attempts all succeeded, usually 1–3 seconds to moving video. Owner explicitly accepts this startup time for now. Earlier startup failures remain historical evidence; their transient cause is not established, but no current reproduction remains after these retests.

No further questions are needed for the agreed short home check. Deferred/unverified: extended endurance, explicit 1080p60 testing, accessibility/Reduce Transparency, lock/interruption/network-loss edge cases, and physical USB fallback/home-return with a running bridge. These are follow-up items, not claimed passes. Keep the legacy relay; any retirement is a separate change. Historical logs below preserve the sequence and version boundaries and do not override this summary.

## Acceptance log — 2026-10-29

- **Initial preflight (historical):** read-only usbmuxd discovery returned zero USB/Wi-Fi connections. T3 `device_list` listed simulators only; no physical iPad was exposed.
- Initial preflight performed no installation or physical playback test. All functional acceptance items below remain pending; retain the legacy relay.
- The owner initially paused acceptance to charge and rejailbreak the iPad, then resumed. Read-only discovery now confirms iPad mini 2 (`iPad4,5`), iOS 10.3.3, reachable over USB and Wi-Fi; TV **0.2.0** was installed at discovery. The owner approved installing 0.3.0 over USB.
- **Pass — installation:** verified the release IPA SHA256, installed over USB (`Install: Complete`), then queried `com.local.iptv`: `CFBundleShortVersionString` is **0.3.0**. No physical playback checks have run.
- **Observed — first launch/settings:** owner opened TV; Gateway URL was blank and the previous Dispatcharr URL was retained. Guide and playback acceptance remain pending.
- **Pass — bridge transport:** owner approved a temporary USB/Mac bridge. Existing SSH key authentication succeeded. A loopback-only reverse SSH forward and Mac guide/HLS adapter reach an isolated gateway candidate on raygun through Tailscale. Fetching the guide from the physical iPad returned NFL 14 games / 3 tiles, NBA 3 / 1, NCAAF 1 / 18 at the snapshot; all stream URLs use iPad loopback. This is transport evidence, not UIKit rendering or playback acceptance.
- **Configured:** while TV was closed, backed up its preferences outside the repo and set only `gateway.baseURL` to the bridge. Preserved the existing Dispatcharr setting. No reinstall or public endpoint. The owner subsequently confirmed populated guide content, RedZone video and good audio; remaining checks are listed below.
- Keep USB connected and the Mac awake during testing; see `tools/tv-usb/README.md` at the repository root for bridge cleanup/restoration.
- Run one interaction at a time and record pass/fail/pending plus actual observations: HLS picture/audio and tap-to-picture time first, then controls, 2+ minute background recovery, rotation and sustained 720p60. Test one stream at a time. Record remaining checks without treating simulator results as physical passes.

### Owner-reported physical results

- **Pass — guide rendering:** after reopening TV with the bridge configured, the owner confirmed populated game cards/network tiles.
- **Pass — HLS picture:** the owner started NFL RedZone and reported that playback worked on the physical iPad. This is direct-HLS playback through the USB/Mac/tailnet adapter, without the legacy TS segmenter.
- **Pass — audio:** in response to the audio/synchronization check, the owner reported that RedZone audio is good.
- **Pending:** measured startup, source resolution/frame rate, sustained smoothness, controls, background recovery, rotation and remaining checklist items. Keep the current RedZone stream as the only active acceptance stream.

## Stopping point and version boundaries

The owner requested a saved handoff. **0.3.0 remains installed**; 0.3.1 is packaged/simulator-checked but not installed. The 0.3.0 guide/RedZone picture/audio results above do not accept the revised UI. The owner also confirmed 0.3.0 tap-to-show and three-second hide, then requested hiding only after first picture. See [backlog](../docs/BACKLOG.md) for resuming 0.3.1 acceptance.

All task-owned test services and the simulator are stopped. **Gateway restoration is unconfirmed:** USB SSH dropped during cleanup; the iPad may still point at the stopped bridge's loopback URL. Original private preferences/config were saved outside Git; restore/provision on reconnect before playback. Do not mark unrun checks as passed.

## Continuation — 2026-10-29 evening

The owner approved installing 0.3.1, but no install was attempted: USB discovery found no device and the usbmuxd Wi-Fi entry returned no model/version. Reconnect and identify the iPad before proceeding; approval persists. The production gateway fixes are deployed and verified independently. Device preferences, installed version and all revised UI checks remain unverified.

### Installation resumed

- **Pass — 0.3.1 USB installation:** owner connected the device; verified iPad4,5 / iOS 10.3.3 and previous TV 0.3.0 / build 3. Verified committed IPA checksum and bundle identity/version/build, then installed with existing owner approval (`Install: Complete`). Independent installed-app query confirms **0.3.1 / build 4**. The earlier discovery blocker is resolved. Private routing/preferences and all 0.3.1 functional/visual checks remain pending. No launch/touch automation or playback test occurred.

## 0.3.2 routing preparation

- **Pass — device transport only:** owner is home and confirmed TV closed. Direct guide request from the physical iPad to the home gateway succeeded. Saved home-primary and USB-fallback defaults, read both back and confirmed Dispatcharr/unrelated settings unchanged. This resolves the stale primary loopback preference. No private profile was present. No video stream was opened.
- **Pass — 0.3.2 installation:** owner-approved USB installation completed after verifying target and IPA checksum/identity; independent installed-app query confirms 0.3.2 / build 5. Physical functional acceptance remains pending. Foundation HTTP fixture tests exercise switching/recovery, not the physical app.
- [x] **Owner-reported pass — 0.3.2 home guide/logos:** owner opened TV and confirmed cards and logos appear. No Mac video bridge was running. Playback and automatic fallback/recovery remain unverified.
- [ ] With an explicitly established USB bridge, confirm unavailable home falls back and returning home selects the home guide on a subsequent refresh.

## Guide and interaction

- [ ] Privately provision gateway/Dispatcharr configuration for 0.3.1; relaunch and verify persistence without a settings screen.
- [ ] Floating bottom NFL / NBA / NCAAF controls are comfortable to tap; no manual refresh/settings controls.
- [ ] Three columns in landscape and two in portrait; rotate while scrolling without clipped cards or stuck touches.
- [ ] Team/network logos remain smooth while scrolling; missing logos show abbreviations.
- [ ] Scores, status and EPG update over several polling cycles without flicker or scroll jumps.
- [ ] Disconnect/reconnect Wi-Fi: last good guide remains, errors clear when the gateway recovers.
- [ ] An unreachable gateway retains the last guide/retries automatically; corrected private configuration takes effect after relaunch.
- [ ] Tapping a pre-game card shows local start time without opening video.
- [ ] VoiceOver reads card/team/status details and labels all controls; Reduce Motion removes control fades.

## Direct Dispatcharr HLS (no relay)

- [x] HLS plays in the app on iOS 10.3.3: owner confirmed RedZone picture and good audio through the USB/Mac/tailnet adapter, which forwards the original endpoint without transcoding or TS segmentation. Keep the relay while remaining physical acceptance is incomplete.
- [ ] Startup on a 24/7 channel is acceptable (aim under 3 s; record actual tap-to-picture time).
- [ ] 720p60 plays smoothly, with audible synchronized audio and no dropped frames.
- [ ] A 1080p60 H.264 channel plays smoothly for several minutes.
- [ ] HEVC-only feeds fail clearly or use a configured server-side H.264 profile; no indefinite spinner.
- [x] **0.3.2 owner pass:** controls stay visible until picture, hide after about 2.5 seconds, tap restores them and Back returns to the guide.
- [x] **0.3.2 owner pass:** short pause/resume works. LIVE/GO LIVE removal is covered by the existing code/simulator evidence.
- [x] **0.3.2 owner pass:** bottom volume slider changes actual sound level; AirPlay works. Single-title layout is captured in prior evidence.
- [ ] Floating glass navigation scrolls smoothly on A7; last rows remain reachable; Reduce Transparency gives a solid capsule.
- [ ] Swipe left/right changes games and shows the correct toast; pre-game targets show start time without streaming.
- [ ] A failed primary feed switches to a backup; all failed feeds show an inline error with a usable Back control.
- [ ] Closing and reopening channels works ten times without overlapping provider streams.
- [x] **0.3.2 owner pass:** portrait → landscape rotation during playback preserves video and correctly positioned, working controls.
- [ ] Home/lock stops video; after 2+ minutes returning re-requests the original endpoint and resumes.
- [ ] Silent switch/audio interruptions and route changes behave sensibly.
- [ ] 30 minutes without memory termination, stutter or increasing live delay.

Test one stream at a time; the provider allows only two connections. Ask before installing on the physical iPad.

## 0.3.2 first playback attempts — owner report

- **Pass — sampled NBA playback:** Cleveland @ Atlanta and Sacramento @ New Orleans worked great, per owner. No measured startup, source-codec, sync or endurance pass inferred.
- **Fail — NFL Panthers @ Packers:** loading, backup toast, black screen, then unavailable-feed error. Existing physical screenshots inspected privately.
- **Fail — NCAAF Troy @ James Madison:** same reported failure.
- Correlated Dispatcharr logs show selected upstreams ending briefly after connection, three retries, then ERROR. First NFL source is labeled 4K, backup is regular; NCAAF source is `NCAAF 02: ESPN2`. Actual codec/placeholder diagnosis remains pending. No corrective server changes or extra playback sessions started.
- Await owner confirmation that playback is stopped before testing one feed at a time. See `docs/VALIDATION-0.3.2.md` for evidence and limits.

## NFL retest after incompatible-source exclusion

Owner refreshed/reopened TV and selected Panthers @ Packers. First attempt displayed a static image and failed. After exiting/reselecting, the picture froze for approximately 4–5 seconds, then playback worked fine. This is a partial pass for playback on the second attempt; first-attempt startup/reliability remains a failure and is not accepted. Owner has not separately confirmed audio synchronization or sustained stability. No agent probe was opened during the owner retest. Next check: leave this single stream playing for one minute and report freezes and audio synchronization.

## Continued physical playback checks — 0.3.2

- **Pass — NFL short stability observation:** owner left Panthers @ Packers playing for approximately one minute and reported it played fine. This does not resolve the failed first attempt or establish longer endurance/measured synchronization.
- **Pass — NCAAF retest:** after returning to the guide and selecting Troy Trojans @ James Madison Dukes, owner confirmed picture and sound work. Earlier failure remains historical evidence of startup unreliability; no blanket reliability pass inferred.
- Current owner stream is NCAAF; do not start concurrent agent probes. Next interaction: show controls, pause, wait five seconds, resume and confirm picture/audio continue.

## Pause/resume — owner pass

On the playing NCAAF stream, owner showed controls, paused for five seconds and resumed; reported picture and sound continue normally ("works great"). This accepts short pause/resume on installed 0.3.2. Long-pause/token-expiry recovery is separate. Next interaction: background TV for more than two minutes and reopen, then report playback recovery. No concurrent agent stream is running.

## Background recovery — owner pass

On installed 0.3.2, owner pressed Home, left TV in the background for just over two minutes, reopened it, and confirmed picture and sound returned without selecting the game again. This accepts the sampled >2-minute recovery path. Rotation, first-picture control timing, AirPlay/volume, longer endurance and initial-start reliability remain separate. Next check: rotate portrait/landscape during playback and verify video/controls remain usable.

## Rotation — owner pass

Owner confirms video keeps playing through portrait then landscape rotation, with controls positioned correctly and working on 0.3.2. Owner asked for all remaining checks together and a short finish; the current summary at the top is the consolidated remaining question set. No agent stream was opened.

## Final short home batch — owner passes

Owner answered yes to controls/Back, actual volume changes and guide interaction (tabs, scrolling/final-card reachability, future-game message). Three NFL open/close attempts all worked, usually 1–3 seconds to playback; owner says that is acceptable for now. Owner additionally confirms AirPlay works. These complete the requested short home checks; deferred coverage is listed in the current summary. No agent streams were opened during owner testing.
