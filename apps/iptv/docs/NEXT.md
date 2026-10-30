# TV next steps

Start with [BACKLOG.md](BACKLOG.md) and the latest section of [HANDOFF.md](HANDOFF.md).

**Prepared:** TV 0.3.2 / build 5 adds home-first gateway selection with optional USB bridge fallback. Focused HTTP tests and iOS 10 release checks pass; physical installation awaits owner approval. [PR #5](https://github.com/timblazing/ios-games/pull/5) remains open; no merge is authorized.

**Installed:** 0.3.1 / build 4 was installed over USB and independently queried on iPad4,5 / iOS 10.3.3. Its physical UI/playback acceptance is pending. The earlier 0.3.0 guide/RedZone picture/audio passes are historical evidence only. Keep the legacy relay.

**Private routing:** the owner is home and confirmed TV closed. Device defaults now store the verified reachable home gateway as primary and the old loopback USB bridge as optional fallback; all unrelated preferences, including Dispatcharr, were preserved. No video bridge is running. 0.3.1 can use the primary; automatic fallback requires 0.3.2. Every refresh in 0.3.2 retries home; failed requests/invalid guides fall back, with last-good data preserved when neither works. The bridge still needs Mac forwarding when away.

**Next interaction:** obtain approval for the prepared 0.3.2 installation, install and verify its version, then ask the owner to open TV and confirm guide/logo rendering before testing one stream at a time. Continue [DEVICE_CHECKLIST.md](../Tests/DEVICE_CHECKLIST.md): first-picture controls, picture/audio, startup, pause/back, rotation, background recovery, A7 smoothness and AirPlay. Test fallback physically only with a deliberately established bridge; HTTP fixture results are not physical acceptance.

**Gateway:** owner-approved group/logo fixes are deployed on raygun. Live guide is populated and 18/18 network logos pass. [Deployment evidence](VALIDATION-0.3.1.md#gateway-deployment--2026-10-29-continuation) and rollback details are saved. No Dispatcharr changes were made.

The owner is rebuilding Dispatcharr with EPG & Sports Editor. Its [setup handoff](DISPATCHARR-SPORTS-SETUP.md) is context; do not execute destructive cleanup without explicit approval. Docker runs only on raygun. Never commit private configuration.
