# Feasibility: T3 Code on iOS 10

Research date: 2026-10-26. This is a proposal, not device-tested compatibility.

## Upstream findings

- [T3 Code](https://github.com/pingdotgg/t3code) has web, desktop, and mobile clients.
- Its [mobile configuration](https://github.com/pingdotgg/t3code/blob/main/apps/mobile/app.config.ts)
  sets the iOS deployment target to 18.0. The mobile app uses Expo and React Native;
  changing a deployment target alone will not port its dependencies to iOS 10.
- The [web dependencies](https://github.com/pingdotgg/t3code/blob/main/apps/web/package.json)
  include Tailwind CSS 4. Its [documented browser baseline](https://tailwindcss.com/docs/compatibility)
  includes Safari 16.4. The web entry uses JavaScript modules; the UI also relies on
  modern CSS. Transpiling JavaScript alone does not address CSS, browser APIs,
  authentication, or performance on an A7 with 1 GB RAM.
- A WKWebView wrapper uses the device's WebKit. It does not upgrade that engine.
- [Remote architecture](https://github.com/pingdotgg/t3code/blob/main/docs/internals/remote.md)
  separates clients from environments over HTTP and WebSocket. Providers, execution,
  files, and durable state belong to the host environment.
- [Remote access](https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md)
  supports direct pairing over a reachable network and T3 Connect. The hosted web
  client requires an HTTPS backend. A computer/server must remain running.
- Upstream is [MIT licensed](https://github.com/pingdotgg/t3code/blob/main/LICENSE).
  Preserve required notices when reusing its code. Protocol compatibility still
  needs investigation against a pinned upstream revision and the user's server.

## Options

| Approach | Assessment |
|---|---|
| Wrap app.t3.codes unchanged | Poor fit: retains modern browser requirements. A wrapper does not provide compatibility. |
| Backport the complete web UI | Technically investigable, but a broad fork: legacy bundling/polyfills, CSS replacement, dependency auditing, auth, and memory work. High ongoing maintenance. |
| Backport the official native mobile app | Poor fit: modern Expo/React Native and native dependencies target a much newer OS. |
| Build a focused legacy web client inside WKWebView | Recommended first investigation: preserve T3's visual language and server behavior with a much smaller browser surface. |
| Build a custom Objective-C/UIKit client | Strong alternative if legacy web rendering or interaction proves unreliable; more UI/protocol integration code. |

## Proposed first milestone

1. Pin an upstream revision and identify the actual target T3 server/version.
2. Audit pairing, credential renewal, message formats, subscriptions, capabilities,
   and reconnect/history recovery. Do not assume a generic REST chat API.
3. Prove authenticated thread listing and streamed conversation reading on iOS 10,
   initially through direct pairing on a trusted reachable network. Validate TLS
   and certificate compatibility without bypassing verification.
4. Add sending prompts, stopping a turn, and permission/approval responses, with
   duplicate-send prevention and reliable reconnect after sleep/backgrounding.
5. Build a small tablet layout: project/thread sidebar, conversation, composer,
   readable code blocks, and Bluetooth keyboard support. Bound rendered history
   to protect the A7's memory budget.
6. Package a Theos IPA after the connection/UI approach works. Device checks must
   cover keyboard, rotation, scrolling, long replies, memory, and wake/reconnect.
   Installing requires the user's go-ahead.

Start with simple bundled HTML/CSS and legacy-compatible JavaScript in WKWebView.
Audit any reused shared runtime before selecting it. If modern auth or transport
libraries cannot run on iOS 10, consider a small authenticated adapter on the host
or native networking; iOS 10 has no NSURLSessionWebSocketTask. Document that added
component and its credential handling before committing to it.

Full terminal emulation, rich document previews, embedded browser streaming, and
complete desktop feature parity are later decisions. No running server, account,
network exposure, or installed app has been changed by this planning work.
