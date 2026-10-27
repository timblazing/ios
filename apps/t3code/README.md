# T3 Mini

Read-only T3 Code companion for a jailbroken iPad mini 2 on iOS 10.3.3.
Version **0.1.0** is a connection and rendering prototype, not the full T3 mobile app.

- Pair with a reachable T3 environment using a one-time pairing link.
- List up to 300 active threads and read the latest user/assistant messages,
  including inherited messages exposed in the server's bounded projection.
- Tap **Refresh** for new replies; this version does not stream or poll automatically.
- Credentials stay in the iPad's Keychain. Only the last environment address is
  saved in preferences. Pairing requests ask for `orchestration:read` only.

Sending prompts, approvals, tools, attachments, archived threads, rich Markdown,
terminal access, and older-history pagination are not implemented. Responses are
bounded to an 8 MB payload, the final 100 turn items, and 30,000 characters per message.

**Release:** [T3Mini-0.1.0.ipa](dist/T3Mini-0.1.0.ipa), Debian package in `packages/`, and [checksums](dist/SHA256SUMS).

## Connect

Keep T3 running on your Mac or Linux host and make it reachable from the iPad's
network. On the host, create a fresh link with:

```sh
t3 pair --scope orchestration:read
```

Paste the complete direct or hosted pairing link into **Pairing link or one-time
credential**, or enter the base environment address and fragment credential
separately. After pairing, leave that field blank to reuse the saved session.
**Forget saved session** removes the current origin's local Keychain entry; it
does not revoke the host session. Use the host's access settings to revoke it.

Pairing links are secrets. Do not put them in screenshots, logs, or Git. Direct
bearer sessions currently last 30 days; an expired session requires a new pairing
link. The app checks protocol 2 and the saved environment identity before sending
saved credentials. It refuses redirects, and HTTPS uses the system's normal
certificate checks. Plain HTTP is permitted for trusted LAN use; its traffic is
not encrypted. T3 Connect account sign-in is not implemented in this prototype.

The host setup is separate. A host bound only to `127.0.0.1` cannot be reached by
the iPad. This app does not enable network access or modify the host's settings.

## Temporary LAN adapter for a loopback desktop host

The repository includes a narrow adapter for this prototype, so testing does not
require restarting or changing the desktop server. On the host Mac:

```sh
python3 tools/t3-mini/lan-gateway.py --listen <Mac-LAN-IP> --port 3774
```

Keep that process running while using the iPad. It forwards only public discovery,
read-only pairing exchange, thread listing, and bounded conversation reads to
`127.0.0.1:3773`. Write endpoints are denied. Use this only on a trusted LAN;
it serves HTTP. Stop with Ctrl-C after testing. Create a pairing link for the
same environment with `t3 auth pairing create --scope orchestration:read
--base-url http://<Mac-LAN-IP>:3774`; paste the link into the app. No private
addresses or pairing credentials are bundled in public releases.

## Build

```sh
export THEOS=~/theos
make package FINALPACKAGE=1 -j4
scripts/package-ipa.sh
```

Build uses Objective-C/UIKit/WebKit/Security, Theos, and the configured iPhoneOS
16.5 SDK with an iOS 10.0 deployment target. Icon generation uses only Python's
standard library. Install the `dist/T3Mini-0.1.0.ipa` with the repo installer or
the bundled `ideviceinstaller`; AppSync Unified and an active jailbreak are required.

`Application/main.m` contains the native network and Keychain bridge.
`Resources/index.html` contains the bundled legacy JavaScript UI. The web view
cannot navigate to remote pages or make its own network requests; it renders
remote text with `textContent`. Only the native bridge handles authentication.

## Private provisioning for a supervised device test

A private install bundle can contain `Pairing.local.plist` with string fields
`url` (base environment URL) and `token` (a one-use pairing credential). The app
reads it natively on page load and automatically pairs only if that origin has
no saved Keychain session. No credential is passed to the web UI. Inject this
file into a separate temporary install staging directory, never into public
source/artifacts. The package script strips it from the public IPA stage and
the source location is gitignored. A public release must also verify that the
`.deb` has no provisioning file. Do not commit or publish private install IPAs.

## Compatibility and validation

The prototype implements these protocol-2 endpoints:

- `GET /.well-known/t3/environment`
- `POST /oauth/token` using a native bearer token exchange
- `GET /api/orchestration/shell`
- `GET /api/orchestration/threads/:id/bounded`

Orchestration requests carry `x-t3-orchestration-protocol: 2`. Endpoint/schema
research was pinned to upstream commit `0b0417a56b2091c87760470833b337eaa0b9a304`.
The server API can change, so compatibility must be rechecked after host updates.
See [the device checklist](Tests/DEVICE_CHECKLIST.md) and
[the original feasibility note](docs/FEASIBILITY.md). Build/package checks do not
prove real iOS 10 networking, Keychain access, touch behavior, or rendering.
