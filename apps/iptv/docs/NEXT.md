# TV next steps

Start with [BACKLOG.md](BACKLOG.md) and the latest section of [HANDOFF.md](HANDOFF.md).

**Current:** TV 0.3.2 / build 5 adds home-first gateway selection with optional USB bridge fallback. Focused HTTP tests and iOS 10 release checks pass; owner-approved physical USB installation and independent version query pass. [PR #5](https://github.com/timblazing/ios-games/pull/5) remains open; no merge is authorized.

**Installed:** 0.3.2 / build 5 was installed over USB and independently queried on iPad4,5 / iOS 10.3.3. Home guide/logos, sampled NBA/NFL/NCAAF playback, pause/resume, >2-minute background recovery and playback rotation pass by owner report; startup reliability and remaining checks are open. Physical USB route switching is unverified. The earlier 0.3.0 guide/RedZone picture/audio passes are historical evidence only. Keep the legacy relay.

**Private routing:** the owner is home and confirmed TV closed. Device defaults now store the verified reachable home gateway as primary and the old loopback USB bridge as optional fallback; all unrelated preferences, including Dispatcharr, were preserved. No video bridge is running. 0.3.1 can use the primary; automatic fallback requires 0.3.2. Every refresh in 0.3.2 retries home; failed requests/invalid guides fall back, with last-good data preserved when neither works. The bridge still needs Mac forwarding when away.

**Next interaction:** owner requested all remaining checks together. The top of [DEVICE_CHECKLIST.md](../Tests/DEVICE_CHECKLIST.md) lists four short home checks: first-picture controls/Back, volume, guide tabs/scroll/future games, and three sequential NFL startup attempts. Do not start concurrent agent streams. AirPlay, extended endurance/accessibility/edge cases and physical USB fallback are deferred/unverified; do not imply completed acceptance or retire the relay. No merge is authorized.

**Gateway:** owner-approved group/logo fixes are deployed on raygun. Live guide is populated and 18/18 network logos pass. [Deployment evidence](VALIDATION-0.3.1.md#gateway-deployment--2026-10-29-continuation) and rollback details are saved. No Dispatcharr changes were made.

The owner is rebuilding Dispatcharr with EPG & Sports Editor. Its [setup handoff](DISPATCHARR-SPORTS-SETUP.md) is context; do not execute destructive cleanup without explicit approval. Docker runs only on raygun. Never commit private configuration.
