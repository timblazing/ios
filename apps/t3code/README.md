# T3 Code

A T3 Code companion for a jailbroken **iPad mini 2 on iOS 10.3.3**. Version **0.3.1** looks like the official T3 Code iOS app's dark theme, uses its app icon, and adds everyday chat to the device-tested T3 Mini reader.

- Browse/search threads: active threads with status labels (Working, Approval, Input, Limited, Failed) on top, and a collapsible Settled shelf below, matching the host's settled/archived/subagent state as the official app does; create threads in an existing project workspace.
- Choose a host provider/model, send or queue follow-ups, watch live replies, and stop turns.
- Respond to resumable approvals and questions, including choices and custom answers.
- Read Markdown, fenced code, and grouped, expandable tool activity ("Ran 2 commands, read 3 files") in a bounded view.
- Keep drafts, recover after wake, and explicitly retry unconfirmed commands with their original IDs.

[IPA](dist/T3Code-0.3.1.ipa) · [Debian package](packages/com.local.t3mini_0.3.1_iphoneos-arm.deb) · [checksums](dist/SHA256SUMS) · [validation](Tests/BUILD_REPORT.md) · [physical checks](Tests/DEVICE_CHECKLIST.md).

## Connect and upgrade

Keep the T3 host running. For a desktop host listening on loopback, run the included adapter on this Mac's private LAN IPv4 address:

```sh
python3 tools/t3-mini/lan-gateway.py --listen <Mac-LAN-IP> --port 3774 --allow-chat
```

This changes the adapter's exposed operations; it does not restart or reconfigure the desktop server. The default without `--allow-chat` remains read-only. Keep the adapter running while using the app. HTTP is only for a trusted LAN: prompts and bearer credentials are unencrypted in transit. HTTPS connections retain normal system certificate verification; certificate checks are never disabled. The adapter itself accepts a loopback HTTP upstream only.

Pairing goes one way: the Mac issues a code and the iPad enters it. The iPad never shows a code, and the iPhone T3 Code app can't add it. Mint a one-time code with the app's chat permissions:

```sh
tools/t3-mini/pair-ipad.sh   # prints the address and a 12-character code, valid once for 10 minutes
```

Open **Connection**, type the address and code, then Connect. Lowercase input is accepted. **Scan QR on Mac** still accepts a pairing link QR (`http://<Mac-LAN-IP>:3774/pair#token=<code>`, e.g. from `t3 auth pairing create --base-url ...`) shown on the Mac's screen. New pairing always requests conversation read and operate access; there is no read-only switch. IP addresses can be entered without `http://`. For a saved session, leave the code blank. The camera permission is requested only when you open the scanner. A code grants access once; the session then stays in Keychain. Direct host reading remains supported, but chat operations in this release require this adapter even if the host is already reachable directly.

**Upgrading keeps `com.local.t3mini`, the executable name, Keychain service/account, and preferences.** Install over the existing app; do not uninstall it. Existing reader sessions remain saved until replaced by a fresh chat pairing. The app never silently expands an old session's authority. A failed credential save preserves the previous Keychain entry. Session expiry requires pairing again. Forget removes the current origin's local Keychain entry; revoke host sessions in the host's access settings.

Pairing links are secrets. Never put them in screenshots, logs, Git, or public packages. No host addresses or credentials are bundled in release artifacts.

## Use

Choose a project with the **All projects** pill or search a title in the sidebar. The gear opens the environment sheet; the compose button starts a new thread. Project/provider/model selectors use in-app dark menus. Connection settings remain open until Done or a successful connection; background refresh does not close them or overwrite edited fields. **New** creates a conversation in the project's existing workspace, with approval required and the selected model; it does not create a worktree. Existing conversation runtime/interaction modes stay on the host. Provider/model changes apply to the next prompt. Providers that require a new conversation for model changes are blocked accordingly.

Enter adds a line; **⌘/Ctrl + Enter** sends. During a running turn, follow-ups queue. **Stop** requests a host thread stop, including delegated work as the host normally does. Pending permission/question cards offer only resumable responses; unavailable requests direct you to the host. Secret-entry requests, attachments, terminal access, full file/diff previews, archived/older-history pagination, and T3 Connect account login are not implemented.

Live updates use foreground bounded snapshot polling: about two seconds while active, eight seconds while idle, with errors backing off to thirty seconds. Network work pauses in the background; wake rechecks environment identity before authenticated reads/writes. The UI preserves a reader's scroll position and offers a scroll-to-latest button when appropriate. A floating **Working** capsule shows elapsed time during a turn.

A prompt is saved locally before dispatch. On a timeout or lost connection, **Refresh and inspect the conversation**, then use **Retry same command** if needed. It reuses the exact command/message IDs; it never auto-resends. **Dismiss after checking** discards only the local pending record. Sending remains blocked for that thread until its pending operation is resolved. Drafts (up to fifty threads) and up to eight pending commands are local app data, including prompt text, scoped by environment origin; credentials remain in Keychain. Treat the device as containing private conversations. Local drafts are not an encrypted vault.

## Design

The interface follows the official app's source ([pingdotgg/t3code](https://github.com/pingdotgg/t3code) `apps/mobile`, MIT): dark tokens (`#0a0a0a` canvas, `#000` sidebar, `#111` surfaces, `#346bf1` accent), DM Sans, the T3 wordmark with its stage badge, round header buttons, filter pills, status labels, the `#161616` user bubble, plain assistant Markdown, the work-log rows, the pill composer with a 30pt send disc, approval/input cards and the inset-grouped Add environment sheet. The split view uses the official sidebar width (32%, 280–380pt) and 960pt feed width. iOS 26 Liquid Glass and SF Symbols aren't available on iOS 10, so the app uses the official non-glass fallback colours and [Tabler](https://tabler.io/icons) icons (MIT; the official Android/web set), built into an inline sprite by `scripts/make-icons.py`. The app icon is the official production icon (`assets/prod/black-ios-1024.png`) on a full-bleed black square, resized by `scripts/make-art.py`. Tap targets stay at least 44pt, so tool rows are taller than the official 28pt.

## Architecture and limits

Objective-C/UIKit hosts a bundled ES5 HTML/CSS/JavaScript interface in WKWebView. Native NSURLSession owns all networking, redirect refusal, environment identity checks, and Keychain access. The page cannot navigate to remote pages or make its own network requests. Markdown escapes remote content; HTML and remote images are not interpreted, and links are displayed as text.

The native transport cancels responses beyond **8 MB while receiving**, rather than checking only after buffering. The page receives at most the newest **80 turn items**, plus older pending questions, **24,000 characters per message**, **4,000 per tool text field**, and a **350,000-character shared text budget**. Pending runtime requests are capped at twenty, threads/projects at three hundred. Earlier history is visibly omitted. Tool details have no syntax highlighter, embedded browser, image decoding, or per-frame animation. Real A7 memory/scroll behavior still requires physical testing.

The adapter forwards discovery, OAuth exchange, shell/bounded reads, and project reads. Its chat bridge opens one bounded authenticated WebSocket RPC per operation:

- `GET /t3-code/config`: filtered provider/model catalog from `server.getConfig`.
- `POST /t3-code/command`: `orchestration.dispatchCommand`, allowing only `thread.create`, `message.dispatch`, `thread.stop`, `runtime-request.respond`, and `thread.model-selection.set`.

It stores no credentials, logs no access URLs or bodies, never retries writes, and rejects other endpoints/command fields. The host still authorizes the bearer scopes. The native command payload limit is 64 KB; the adapter's request limit is 128 KB. Protocol and design evidence are in [PROTOCOL.md](docs/PROTOCOL.md).

## Build and test

```sh
cd apps/t3code
export THEOS=~/theos
make package FINALPACKAGE=1 -j4
scripts/package-ipa.sh
scripts/check-release.py
node --test Tests/test-ui.js Tests/test-picker.js
Tests/browser-smoke.sh                 # agent-browser + Python 3 + curl
cd ../..
python3 -m unittest discover -s tools/t3-mini/Tests -v
```

The configured iPhoneOS 16.5 SDK resolves locally to 16.4; the deployment target stays **10.0**. The internal app/executable remains T3Mini intentionally; the display and release IPA names are T3 Code. Version both `control` and `Resources/Info.plist`, and regenerate checksums when packaging. Public `.deb`/`.ipa` artifacts are committed deliberately.

Normal device setup uses a typed code from `tools/t3-mini/pair-ipad.sh` (QR scanning is optional). Older supervised tests used separate private IPAs with a one-use `Pairing.local.plist` (`url`, `token`) injected into temporary staging outside the repo. The release script excludes it, and `check-release.py` checks both formats. Installed tests since 0.2.1 use the public IPA and normal pairing. No pairing credentials are included in release artifacts.

## Remote access on this iPad

Direct pairing works anywhere the iPad can reach the host's address. The official Tailscale iOS client requires iOS 15+, so this iOS 10 iPad cannot join a tailnet using that client. A home subnet router alone does not enroll a remote device; the iPad would need a compatible VPN path or a local gateway/travel router running Tailscale. No VPN, router, Tailscale Serve/Funnel, or public network exposure is configured by this app.

T3 Connect's official managed-relay flow uses account authentication and DPoP-bound access credentials. Backporting that flow to native iOS 10 requires separate authentication, cryptography, renewal, and real relay testing; it is not available in this release. Home LAN pairing remains the working path while that compatibility is investigated. See [official remote access](https://github.com/pingdotgg/t3code/blob/9bc0c334383a43af5390283e9b10f999acc021b8/docs/user/remote-access.md) and [Tailscale iOS requirements](https://tailscale.com/docs/install/ios).
