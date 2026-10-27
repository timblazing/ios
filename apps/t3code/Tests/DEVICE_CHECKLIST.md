# T3 Chat 0.2.1 physical device checks

Target: iPad mini 2 / iPad4,5 on iOS 10.3.3. Automated and real-host protocol results are in [BUILD_REPORT.md](BUILD_REPORT.md). Check boxes below require the user's physical verification.

User observations so far: 0.1.0 thread/conversation reading worked. On 0.2.0, threads/conversations looked like a good starting point and no other noticeable keyboard/scroll/rotation issue was reported; pairing was still read-only. The persistent access banners, native menus and Connection auto-closing prompted 0.2.1. These observations do not prove the new version's behavior.

First checks after force-closing and reopening the upgraded app:

- [ ] Open Connection, edit Address, wait at least 15 seconds. Confirm the sheet remains open and input is retained.
- [ ] Open All projects. Confirm a dark in-app menu appears instead of the native iOS selector; choose a project.
- [ ] Tap Scan pairing code, allow the camera, scan a fresh code shown on the Mac. Confirm chat controls become available and no access/count banner clutters the conversation.
- [ ] Alternatively, pair using address + code or a full pairing link; confirm bare LAN IP addresses work.
- [ ] Send one short prompt in the validation conversation. Confirm exactly one copy appears and the reply updates automatically.
- [ ] Lock/unlock or background/reopen. Confirm the saved session reconnects without another pairing code and a draft survives.

Further checks:

- [ ] Create a conversation in a selected project, choose provider/model, send a prompt and confirm desktop uses that selection.
- [ ] Stop a running turn. Confirm the host stops it and the iPad reflects completion/interruption.
- [ ] Answer a question and an approval request; verify the host resumes the intended turn.
- [ ] Toggle Wi-Fi during a send. Inspect the transcript before Retry same command; confirm no duplicate user message.
- [ ] Keyboard leaves composer/send controls visible. Enter inserts a line; Bluetooth ⌘/Ctrl+Enter sends once.
- [ ] Rotate with keyboard open/closed; close/open custom menus and scanner in both orientations.
- [ ] Scroll long text/code while updates arrive. Confirm reading position stays stable and Latest reply jumps down.
- [ ] Cancel/deny camera permission and background while scanning; confirm camera closes and manual pairing stays available.
- [ ] Force-close/relaunch and confirm Keychain session persistence. Rename/update must not require uninstalling the app.
- [ ] Invalid/expired/consumed pairing codes give recoverable errors without exposing credentials.

Remote access is a separate network/authentication check. This iPad cannot use the current Tailscale iOS client. No remote route, T3 Connect account sign-in, or TLS compatibility for a new remote endpoint is claimed.
