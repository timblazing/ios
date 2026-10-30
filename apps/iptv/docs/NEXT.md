# TV next steps

Start with [BACKLOG.md](BACKLOG.md) for the prioritized queue and [HANDOFF.md](HANDOFF.md) for the saved session state.

**Prepared:** TV 0.3.1 / build 4, packaged and simulator-checked; not installed on the physical iPad. [PR #5](https://github.com/timblazing/ios-games/pull/5) is for owner review, not automatic merge.

**Installed/partially accepted:** 0.3.0 on iPad mini 2 / iOS 10.3.3. Owner confirmed guide, RedZone picture and good audio via the temporary USB/Mac/tailnet bridge. Remaining physical checks and the revised UI need acceptance. Keep the legacy relay.

**First resume action:** reconnect/read-only identify the iPad and repair private gateway configuration. The bridge was shut down, but its loopback preference may remain because USB SSH dropped before restoration could be confirmed. Original preferences/config are saved privately outside Git. The owner approved installing 0.3.1 in the 2026-10-29 continuation; that approval persists. Installation is blocked until read-only discovery identifies the iPad. Then work through one device interaction at a time.

The current direction is a floating bottom glass-style league capsule over scrolling guide content, automatic polling only, private provisioning without settings UI, one player title, AirPlay top right and a 2.5-second hide delay after first picture. Old top-bar/settings/LIVE-button designs are historical references, not the current UI specification.

The owner is also rebuilding Dispatcharr with EPG & Sports Editor. Its [setup handoff](DISPATCHARR-SPORTS-SETUP.md) is backlog context; do not execute destructive cleanup without explicit approval. Recheck current server/plugin state before gateway work. Run Docker only on raygun; one video stream at a time; never commit private configuration.

**Gateway update:** the owner-approved group/logo fixes are now deployed on raygun, with populated live guide and 18/18 network-logo endpoint checks. See the latest [handoff](HANDOFF.md#continuation--2026-10-29-evening) and [deployment evidence](VALIDATION-0.3.1.md#gateway-deployment--2026-10-29-continuation). Dispatcharr setup and physical rendering/playback acceptance remain pending.
