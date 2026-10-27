# T3 Code 0.3.0 validation

Date: 2026-10-26 (local). Target: iPad4,5, iOS 10.3.3.

## Automated checks

- Theos arm64 device build passed, including the new AVFoundation QR scanner. The configured 16.5 SDK resolves to installed SDK 16.4. `vtool` reports `LC_VERSION_MIN_IPHONEOS` version **10.0**. Only the known Theos obsolete linker warning was reported.
- Public 0.2.1 IPA/DEB metadata, bundled source/resource equality, fonts, private-file exclusions, and all release checksums passed using `scripts/check-release.py`. Bundle ID/executable/Keychain service remain `com.local.t3mini` / `T3Mini` / `com.local.t3mini.session`.
- Gateway Python tests: **7 passed**. Coverage includes real mock HTTP/WebSocket round trips, masking, fragmentation, protocol/control pings, scope/auth rejection, opt-in endpoints, catalog privacy, limits, and no automatic replay of uncertain writes.
- JavaScript tests: **14 passed**. Coverage includes safe bounded Markdown, incomplete streaming fences, duplicate/stale-response protection, scroll/draft semantics, request capabilities, UUIDs and menu placement at iPad/phone/keyboard-reduced sizes.
- `Tests/browser-smoke.sh` passed with headless Chromium at 1440×900, 1024×768, 768×1024 and 393×852: send/queue/stop/create payloads, duplicate blocking, same-ID retry, acknowledgements, draft switching, stale snapshots, question/approval responses, background-disabled controls and no horizontal overflow or small visible button targets. Browser console/errors were empty.
- The reported Connection bug was reproduced with a failing browser regression: a `threads` refresh hid the form. The regression now passes; background refresh keeps it open and preserves an edited address. Custom project/model menus, menu preservation during refresh, outside dismissal, scanner bridge invocation and removal of persistent access/count banners also passed browser checks.
- Screenshots were inspected for the iPad chat/connection views and phone layout. These are synthetic sanitized conversations, not screenshots of the user's private threads. Chromium checks do not establish iOS 10 WebKit or camera behavior.
- T3 Code device support previously reported that it could not communicate with simulator support. No simulator runtime result is claimed.

## Real host integration

Host remained running: **0.1.3-nightly.20261026.3726**, protocol **2**, on its existing loopback listener. The separate trusted-LAN adapter was replaced with its opt-in chat version; the desktop T3 process was not restarted.

A separate validation session requested exactly conversation read + operate permissions. Through the adapter, real discovery, shell/bounded reads and filtered provider/model catalog succeeded. A labeled validation thread was created in the existing ios-games project workspace using GPT-6 Luna, approval required. Test prompts instructed the model not to use shell/file tools.

- The host accepted create/send; the model replied **“T3 Code connected.”**
- Replaying the exact create/send commands returned the same sequence receipts. The transcript contained one copy of each message.
- A real user-input request was surfaced in the bounded projection, answered via `runtime-request.respond`, and the model continued with **“You chose Blue.”**
- A newly started turn was stopped; its subsequent projection reported **interrupted**.

Permission response buttons were tested against synthetic resumable approval data and mock RPC. A real provider permission approval was not triggered. Live host checks exercise the gateway/protocol, not the iPad's native transport or physical controls.

## Physical installation and user feedback

- 0.1.0: user confirmed threads and conversations worked on the iPad.
- 0.2.0: Wi-Fi installer completed; installed metadata reported T3 Code 0.2.0. User said threads/conversations were a good starting point and reported no other noticeable device issues, but disliked the persistent read-only/count messages and native selectors. The connection fields closed during polling. Chat pairing on that installation remained read-only; no send/wake acceptance is claimed.
- 0.2.1: the public IPA was installed over Wi-Fi; installer completed and the device reported T3 Code 0.2.1 under the original bundle ID. Normal QR/code pairing, camera permission/recognition, actual send, new menus, connection persistence and wake/keyboard/rotation/scroll behavior remain focused device checks until the user confirms them.
- 0.2.1 feedback: the user tried scanning the iPad's pairing sheet with the iPhone T3 Code app. That sheet showed a decorative QR glyph, not a code, and the iPad is the client, so it could never work; the sheet also gave no code to type.
- 0.2.2: replaced the glyph with Mac-side steps, made the 12-character code field visible and case-insensitive, added `tools/t3-mini/pair-ipad.sh`, and kept QR scanning as a secondary button. Automated: clean Theos build (iOS 10.0 minimum), `check-release.py`, JS and gateway tests, browser smoke. Installed over Wi-Fi; device reports 0.2.2. User-verified on the iPad: typed-code pairing connected, and a message sent from T3 Code reached the host conversation. The user believes Connection stayed open (not confirmed precisely) and confirmed All projects uses the dark menu, but its arrow sat low and far from the label.
- 0.2.3: the picker chevron is drawn in CSS and vertically centered; All projects is a pill with the arrow beside the label, as in the official mobile app. Automated checks above rerun and pass; installed over Wi-Fi, device reports 0.2.3. On the device the arrow then sat too high: iOS 10 WebKit ignores flex layout on `<button>`, so the centering only worked in desktop browsers.
- 0.3.0: renamed to T3 Code (display name, docs, IPA, adapter endpoints `/t3-code/*`; bundle ID, executable, Keychain and saved drafts unchanged so pairing survives). Official production app icon. UI rebuilt to the official mobile app's dark design from its source (sidebar brand/badge, round header buttons, search, filter pill, Working/Settled shelves with status labels, user bubble, work-log groups, pill composer with send/stop discs, floating Working capsule, approval/input cards, inset-grouped environment sheet). Picker contents now lay out in a flex `<span>` inside each button. Automated: clean Theos build (iOS 10.0 minimum, no warnings), `check-release.py`, 14 JS and 7 gateway tests, browser smoke (tap targets ≥44pt and no overflow at 1440×900, 1024×768, 768×1024 and 393×852), and showcase screenshots. LAN adapter restarted for the renamed endpoints; desktop server untouched. Installed over Wi-Fi; device reports T3 Code 0.3.0. Not yet checked by the user: the look on the device, arrow alignment, home screen icon, and whether the saved session reconnected.

The Mac's trusted-LAN adapter stays running for the installed client. Public artifacts contain no host configuration, pairing credential, or account session. Private one-use pairing material stays outside the checkout. Managed T3 Connect sign-in and remote network reachability are not verified or implemented in this release.
