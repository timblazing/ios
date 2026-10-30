# IPTV backlog and next steps

Start here when the owner says “let’s work on my IPTV backlog/next steps.” Read [HANDOFF.md](HANDOFF.md), the app [README](../README.md), and repository `AGENTS.md` before acting. The current work is on `docs/t3-device-panel`, [PR #5](https://github.com/timblazing/ios/pull/5); check its live status rather than assuming it merged.

## 1. Home acceptance complete; follow-up coverage

- [x] Identified iPad mini 2 / iPad4,5 / iOS 10.3.3, installed and independently verified **0.3.2 / build 5**; owner playback confirms the working device setup.
- [x] Repaired private routing at home: backed up settings, verified home gateway reachability from the iPad, saved home primary plus optional USB fallback, and verified unrelated preferences unchanged. Automatic selection is installed in 0.3.2; bridge operation when away remains separate.
- [x] Installed the owner-approved **0.3.1 IPA / build 4** over USB after identifying iPad4,5 / iOS 10.3.3 and verifying checksum/identity. Independent installed-app query confirms the version/build. Superseded by installed 0.3.2 and its acceptance below.
- [x] Owner approved **0.3.2 / build 5**; verified USB target and IPA checksum/identity, installed successfully, and independently queried installed version/build. Agreed short home acceptance passes; physical USB fallback remains deferred.
- [x] Complete agreed short home checks: guide/logos/tabs/scroll/future game, sampled NBA/NFL/NCAAF playback, first-picture controls/Back, volume/AirPlay, pause/resume, >2-minute Home/background recovery, rotation, and three NFL starts at owner-accepted 1–3 seconds. See current [device checklist summary](../Tests/DEVICE_CHECKLIST.md).
- [ ] Deferred coverage: physical USB fallback/home-return, extended endurance/explicit 1080p60, accessibility/Reduce Transparency and lock/interruption/network-loss edge cases.
- [ ] Leave the legacy relay compiled until remaining physical acceptance supports removing it; remove it separately, with retained regression coverage until then.

## Playback issue follow-up

- [x] Owner approved and deployed the tested gateway exclusion change/private setting. Source and `.env` backed up; running source matches checkout, incompatible source is absent from every guide selection and only the regular H.264 NFL feed remains. Dispatcharr is unchanged. See latest handoff for rollback.
- [x] Physical retest: NFL plays on retry and stayed smooth for approximately one minute; NCAAF picture/sound now work.
- [x] Current startup accepted: three subsequent NFL open/close attempts all worked, usually 1–3 seconds; owner accepts this for now. Earlier failures remain historical with an unproven transient cause; reinvestigate if they recur.

## 2. Review and finish the prepared changes

- [x] Review PR #5 (2026-10-29 continuation: focused tests, fresh compile, release checksums and IPA metadata pass). It includes the 0.3.1 UI/packages plus earlier guide/logo fixes, USB tooling, device-panel guidance and validation. Do not merge without the owner's instruction.
- [x] Owner-approved deployment of the two reviewed gateway fixes on **raygun** completed 2026-10-29 (00:51 UTC on Oct 30). Running source matches the checkout; all three generated leagues are populated and all 18 network logos return valid 96×96 PNGs. See [deployment evidence](VALIDATION-0.3.1.md#gateway-deployment--2026-10-29-continuation). `/health` alone is insufficient: it reported channels while the guide was empty due to changed provider groups.
- [x] Rechecked current Dispatcharr M3U groups before deploying (NFL 18, NBA 14, NCAAF 68 channels); the owner is rebuilding them concurrently. The gateway fix recognizes league tokens in labels such as `US| NFL PPV`. Network-logo source owner is corrected to `tv-logo/tv-logos`.
- [x] Owner confirms home guide/cards/logos render in the physical app, separately from the 18/18 gateway endpoint checks.

## 3. Dispatcharr / EPG & Sports Editor

- [ ] Work through [the owner-provided setup handoff](DISPATCHARR-SPORTS-SETUP.md) with the owner and current [upstream plugin docs](https://github.com/jstevenscl/epg-and-sports-editor).
- [ ] Inventory and back up the current setup. Get explicit approval before deleting channels/EPGs or running teardown; the attached clean-slate plan is context, not an instruction to execute now.
- [ ] Align exact group labels and enabled Sports Editor sections; confirm nonzero scanned channels for NFL, NBA and NCAAF, renamed matchups/logos, and Pregame/Live/Postgame blocks at Central times.
- [ ] Check TV gateway matching, title/EPG behavior and Jellyfin after the plugin setup. Treat prior plugin claims/settings as a handoff to verify, not accepted facts.

## 4. Independent remote access and maintenance

- [ ] Choose a permanent home/travel configuration and preconfigure it privately. The Mac/USB route was temporary; see [USB bridge tooling](../../../tools/tv-usb/README.md).
- [ ] If buying a router, recheck prices/availability and official Tailscale support. Slate Plus GL-A1300 was suggested within the earlier $69.99 budget. At the later sub-$40 budget, Opal GL-SFT1200 was suggested only with a separate home WireGuard setup; it does not officially support Tailscale. No purchase or VPN setup was performed.
- [ ] Research reducing/automating re-jailbreaking after restart, starting with [LukeZGD/tns-sockport](https://github.com/LukeZGD/tns-sockport). Feasibility is unverified; no boot/jailbreak changes were made. See shared [personal notes](../../../docs/PERSONAL_TODO.md).
