# TV next steps

**Current checkpoint:** TV **0.3.2 / build 5** is installed and the agreed short home acceptance checks are complete. [PR #5](https://github.com/timblazing/ios/pull/5) is ready for owner review; no merge is authorized. See [HANDOFF.md](HANDOFF.md), [validation](VALIDATION-0.3.2.md) and the current summary in [DEVICE_CHECKLIST.md](../Tests/DEVICE_CHECKLIST.md).

**Owner-reported passes:** home guide/cards/logos, league tabs/scrolling/future-game messages, sampled NBA/NFL/NCAAF playback, first-picture control timing/tap/Back, volume, AirPlay, short pause/resume, >2-minute Home/background recovery and playback rotation. Three sequential NFL starts worked in usually 1–3 seconds, explicitly acceptable to the owner for now. Prior first-start failures are preserved historically; the transient cause is not proven. Reinvestigate if they recur.

**Deployed:** gateway group/logo fixes plus private exclusion of the probe-confirmed incompatible NFL HEVC primary. The regular H.264 NFL feed remains. Generated leagues, running source and network-logo endpoints were verified; source/private-environment backups and rollback are in the handoff. Dispatcharr configuration was unchanged.

**Routing:** private device defaults store home primary and optional loopback USB fallback. Every refresh retries home; failed requests/invalid guides try the fallback and preserve last-good data if neither succeeds. The Mac bridge must be running for offsite fallback. No bridge or temporary agent process remains running.

**Deferred work:** physical USB fallback/home-return, extended endurance and explicit 1080p60, accessibility/Reduce Transparency and lock/interruption/network-loss edge cases. Keep the legacy relay and consider retirement in a separate scoped change. No further short home test questions are pending.

Dispatcharr/EPG & Sports Editor setup and permanent travel access remain separate items in [BACKLOG.md](BACKLOG.md). Its setup/teardown notes do not authorize destructive changes. Docker runs only on raygun; never commit private configuration.
