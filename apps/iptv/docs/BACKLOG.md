# IPTV backlog and next steps

Start here when the owner says “let’s work on my IPTV backlog/next steps.” Read [HANDOFF.md](HANDOFF.md), the app [README](../README.md), and repository `AGENTS.md` before acting. The current work is on `docs/t3-device-panel`, [PR #5](https://github.com/timblazing/ios-games/pull/5); check its live status rather than assuming it merged.

## 1. Resume the physical iPad session

- [ ] Reconnect and identify iPad mini 2 / iPad4,5 / iOS 10.3.3 using read-only tools; confirm jailbreak and installed version. Last verified installed app: **0.3.0**.
- [ ] Fix the gateway configuration before playback: the temporary USB bridge is stopped and the iPad may still have its loopback URL. Original preferences and bridge configuration are saved privately at `~/.config/ios-games/iptv/session-2026-10-29/` on this Mac. Restore just the previous gateway preference or establish the chosen new private route; preserve Dispatcharr and unrelated settings. No private values in Git/chat/screenshots.
- [ ] Ask before installing the prepared **0.3.1 IPA**. The prior approval covered 0.3.0 only. New UI has no settings or refresh controls; provision privately first. See [private configuration](../README.md#private-configuration).
- [ ] Run [DEVICE_CHECKLIST.md](../Tests/DEVICE_CHECKLIST.md) one interaction at a time, recording pass/fail/pending for the actual version. Prioritize picture/audio, measured tap-to-picture, first-picture control timing, pause/resume/back, 2+ minute background recovery, rotation and smooth 720p60. Physical AirPlay/volume and glass rendering/performance are also pending. One video stream at a time.
- [ ] Leave the legacy relay compiled until remaining physical acceptance supports removing it; remove it separately, with retained regression coverage until then.

## 2. Review and finish the prepared changes

- [ ] Review PR #5. It includes the 0.3.1 UI/packages plus earlier guide/logo fixes, USB tooling, device-panel guidance and validation. Do not merge without the owner's instruction.
- [ ] Deploy the reviewed gateway fixes on **raygun**, then verify generated guide data and logos. Production was not redeployed in this session; the temporary candidate was removed. `/health` alone is insufficient: it reported channels while the guide was empty due to changed provider groups.
- [ ] Recheck current Dispatcharr groups and plugin output before deploying; the owner is rebuilding them concurrently. The gateway fix recognizes league tokens in labels such as `US| NFL PPV`. Network-logo source owner is corrected to `tv-logo/tv-logos`.
- [ ] Validate logos in the physical app. Corrected URLs already passed 18/18 through the gateway, but that is endpoint evidence, not device rendering acceptance.

## 3. Dispatcharr / EPG & Sports Editor

- [ ] Work through [the owner-provided setup handoff](DISPATCHARR-SPORTS-SETUP.md) with the owner and current [upstream plugin docs](https://github.com/jstevenscl/epg-and-sports-editor).
- [ ] Inventory and back up the current setup. Get explicit approval before deleting channels/EPGs or running teardown; the attached clean-slate plan is context, not an instruction to execute now.
- [ ] Align exact group labels and enabled Sports Editor sections; confirm nonzero scanned channels for NFL, NBA and NCAAF, renamed matchups/logos, and Pregame/Live/Postgame blocks at Central times.
- [ ] Check TV gateway matching, title/EPG behavior and Jellyfin after the plugin setup. Treat prior plugin claims/settings as a handoff to verify, not accepted facts.

## 4. Independent remote access and maintenance

- [ ] Choose a permanent home/travel configuration and preconfigure it privately. The Mac/USB route was temporary; see [USB bridge tooling](../../../tools/tv-usb/README.md).
- [ ] If buying a router, recheck prices/availability and official Tailscale support. Slate Plus GL-A1300 was suggested within the earlier $69.99 budget. At the later sub-$40 budget, Opal GL-SFT1200 was suggested only with a separate home WireGuard setup; it does not officially support Tailscale. No purchase or VPN setup was performed.
- [ ] Research reducing/automating re-jailbreaking after restart, starting with [LukeZGD/tns-sockport](https://github.com/LukeZGD/tns-sockport). Feasibility is unverified; no boot/jailbreak changes were made. See shared [personal notes](../../../docs/PERSONAL_TODO.md).
