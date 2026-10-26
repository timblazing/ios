# Apps for iPad mini 2

Non-game apps live in `apps/<name>/`, alongside `games/<name>/`.
Each implemented app should be a self-contained Theos project with its own README,
Makefile, control, Resources, scripts, Tests, and release artifacts, following the
same iOS 10.0 deployment target and Objective-C conventions as the games.

| App | Status |
|---|---|
| [T3 Code client](t3code/) | Feasibility and proposed approach; no implementation yet |

Networking is part of the proposed T3 client. The existing offline-game policy
continues to apply to games; app-specific network behavior must be documented.

The root installer currently discovers `games/` only. Until app discovery is
implemented, its “Select IPA file...” option can select an app IPA.
