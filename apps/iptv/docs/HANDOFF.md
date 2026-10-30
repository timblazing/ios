# TV handoff — 2026-10-29

The owner asked to archive the chat and stop at a saved checkpoint. Resume from [BACKLOG.md](BACKLOG.md). Do not infer authorization to install or merge from this handoff.

## 0.3.2 installation — 2026-10-29 evening

The owner approved installing 0.3.2. Reverified USB target iPad4,5 / iOS 10.3.3, IPA checksum and bundle identity/version/build, then installed (`Install: Complete`). Independent installed-app query confirms **0.3.2 / build 5**. Earlier approval/install-pending statements below are historical. The owner has been asked to open TV and confirm guide cards/logos; that response and all physical playback/fallback acceptance remain pending. No video bridge is running, no stream was opened and no app launch/touch was automated. Home/USB preferences were provisioned before upgrading, as recorded below.

## Automatic gateway selection — 2026-10-29 evening

The owner asked TV to choose between home and USB routes automatically. Prepared **0.3.2 / build 5** implements home-first requests, then optional `gateway.fallbackBaseURL` on HTTP/network/timeout/parse failure. Each later refresh retries home. Guide data, absolute stream addresses, logo origin and ETag remain associated with the successful endpoint. Exhausting both routes preserves the last valid guide; cancellation suppresses stale completions. [0.3.2 validation](VALIDATION-0.3.2.md) records tests and package checks. New build installation awaits explicit approval; **0.3.1 / build 4 remains installed**.

The owner is at home and confirmed TV closed. Verified the home gateway directly from the physical iPad without opening video. Backed up preferences privately under `~/.config/ios-games/iptv/acceptance-2026-10-29/`, then used mobile preferences to save the home primary plus the existing loopback bridge as fallback. Read-back verifies both and confirms all other preferences are unchanged. No private launch profile was present. The stale-primary loopback issue is resolved. No video bridge or reverse forwarding is running; automatic selection cannot create a bridge when away.

## Physical installation resumed — 2026-10-29 evening

The owner connected the iPad by USB. Read-only queries confirmed iPad4,5 / iOS 10.3.3 with TV 0.3.0 / build 3 installed. After verifying the committed IPA checksum and bundle identity/version/build, installed the owner-approved TV 0.3.1 / build 4 over USB (`Install: Complete`). A separate installed-app query confirms 0.3.1 / build 4. The earlier connectivity/install blocker below is resolved. Private gateway preferences and physical guide/playback acceptance remain pending; installation alone does not validate them. No app launch or touch was automated.

## Continuation — 2026-10-29 evening

This section supersedes the earlier production-deployment and installation-approval status below. The owner explicitly approved deploying the gateway fixes and installing the prepared 0.3.1 IPA; no merge was authorized.

- Deployed only the provider-group matching and network-logo repository fixes to production `tv-gateway` on raygun. Verified running-container source SHA256 `84806f368af8c1ab99de506394286a8bb5328fa8bb8956670c5dd08140ca5777` matches this checkout. Dispatcharr configuration was unchanged; no video streams were opened.
- Live guide: NFL 14 games / 3 tiles, NBA 13 / 1, NCAAF 1 / 67 at the verification snapshot; 100 source channels and no source errors. All 18 network-logo endpoints return HTTP 200, `image/png`, 96×96.
- Original deployed source is backed up on raygun at `~/docker/tv-gateway/backups/pr5-20261030T005127Z/gateway.py`. To roll back only these fixes, restore that file to `~/docker/tv-gateway/gateway.py`, then run `docker compose up -d --build tv-gateway` from that directory and verify guide/health. No Mac containers were started.
- Fresh Theos compile, iOS 10.0 minimum, guide/configuration tests, gateway 8 tests, bridge 5 tests, all six release checksums, and prepared IPA integrity/identity/version/build/private-filename checks pass.
- **Physical installation remains blocked:** no USB device was found. usbmuxd listed a Wi-Fi entry, but device-information queries returned no model/version. No install was attempted, and the iPad's current installed version and preferences could not be reverified. The installation approval persists; reconnect and positively identify iPad4,5 / iOS 10.3.3 before installing. Physical interaction remains owner-driven when the legacy device is unavailable in the Device panel.
- The possibly stale loopback gateway preference still needs inspection/repair. No bridge, simulator or temporary server was started by this continuation; production gateway remains running.

## Repository and delivery

- Base `main`: `97c5949`, TV 0.3.0 via merged PR #4.
- Current branch: `docs/t3-device-panel`; [PR #5](https://github.com/timblazing/ios-games/pull/5), left for owner review. No merge performed.
- Prepared package: **0.3.1**, bundle build **4**, in `dist/` and `packages/`, with updated `SHA256SUMS`. Not installed on the physical iPad.
- Unrelated archived files and backup branch were not touched.
- T3 Device panel workflow documented here and in [scores PR #7](https://github.com/timblazing/scores/pull/7). Shared Claude Code/Codex instructions were updated through their common linked `skills/config/AGENTS.md` (skills commit `b59f6fe`). Check live PR state before resuming.

## What changed

- Guide: automatic polling remains; manual refresh and server-settings UI removed. NFL/NBA/NCAAF buttons sit in a centered floating glass-style capsule at the bottom. The collection fills the screen and scrolls behind it; bottom inset keeps the final cards reachable. iOS 10 `UIVisualEffectView`, restrained sheen/rim, translucent selection; solid fallback under Reduce Transparency. Native iOS 26 Liquid Glass APIs are not used.
- Player: one matchup/channel title; no duplicate subtitle or LIVE/GO LIVE functionality. AirPlay is top right; volume and pause stay at the bottom. Unavailable AirPlay routes show a dim indicator. Controls remain visible while loading and hide 2.5 seconds after the video layer has a picture and playback is running; pause/errors keep controls available.
- Private configuration: existing device defaults remain usable; a validated on-device profile can preconfigure keys at launch. No real URLs are embedded in source, resources or public packages. Build/package guards reject private profile filenames and macOS metadata.
- Gateway: fixed the logo source repository typo and exact-group mismatch after Dispatcharr group labels acquired provider prefixes/suffixes. Prepared fixes passed tests and a temporary candidate populated the guide. Production gateway was not changed.
- Added [Dispatcharr setup handoff](DISPATCHARR-SPORTS-SETUP.md) and backlog items. Its teardown/deletion steps were not executed.

## Verification and limits

Physical **0.3.0**: owner-approved USB install completed; installed version queried. Owner confirmed populated guide, NFL RedZone video and good audio via the USB/Mac/tailnet bridge. Tapping showed controls and they hid after three seconds; owner then requested the new behavior. Startup timing, resolution/frame rate, sustained smoothness, rotation, background recovery and AirPlay were not accepted. Keep the relay.

Prepared **0.3.1**: Theos arm64 package build passed without compiler/API warnings (documented Theos linker warning only), `vtool` confirms iOS 10.0 minimum. Guide/configuration tests pass; gateway 8 tests and USB adapter 5 tests pass. IPA/DEB identity, version/build, private-file/macOS-metadata exclusions and all release checksums pass. See [0.3.1 validation](VALIDATION-0.3.1.md).

Simulator, through T3 Device panel: checked portrait/landscape guide, all three league buttons, bottom scroll reachability and a synthetic delayed HLS player. Controls stayed visible during approximately 9 seconds before first picture, then hid after 2.5 seconds. One centered title and top-right AirPlay location are captured in screenshots. This is modern simulator evidence, not physical iOS 10 acceptance. Real AirPlay routing and A7 blur performance remain pending.

## Shutdown / private state

- Owner closed the physical TV app before simulator work; no new physical package was installed.
- Task simulator was closed/shut down. Fixture server, simulator adapter, iPad adapter, USB `iproxy`, and both SSH forwarding processes were stopped. Raygun's `tv-gateway-usb-acceptance` container and its temporary source file were removed; production `tv-gateway` was left alone.
- The iPad USB SSH connection dropped during cleanup (`Connection reset by peer`) before restoration could be confirmed. **Assume `gateway.baseURL` may still be `http://127.0.0.1:19494` pointing to the stopped bridge.** Recheck and restore/provision on reconnect. Dispatcharr was never changed by the bridge setup.
- Durable private files on this Mac: `~/.config/ios-games/iptv/session-2026-10-29/` (mode 700, files mode 600), including `config.json`, `simulator-config.json` and `preferences-before.plist`. These contain private addresses/settings and are intentionally outside Git. The portable synthetic HLS fixture and original simulator timing recording are also saved in this private directory; they can be reused without this chat. The original gateway was absent/blank; preserve other preferences when restoring.
- Private shell/session IDs and temporary sockets are not a durable restart mechanism. Recreate forwarding using `tools/tv-usb/README.md` only after identifying the current device and confirming the owner wants it. Never expose the proxy publicly or run containers on this Mac.
