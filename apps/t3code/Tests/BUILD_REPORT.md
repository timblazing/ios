# T3 Mini 0.1.0 validation

Date: 2026-10-26.

- Theos device build and IPA/DEB packaging passed. The configured 16.5 SDK
  resolves to installed SDK 16.4; `vtool` confirms minimum iOS 10.0.
- Only the known Theos obsolete linker warning was reported.
- Public IPA/DEB metadata and checksums passed; no private provisioning file.
- Native endpoint protocol was checked against T3 Code nightly
  `0.1.3-nightly.20261026.3726`: discovery, read-only token exchange, shell,
  and bounded conversation all succeeded through the temporary LAN adapter.
- Gateway tests verify allowed reads and reject write routes/scope escalation.
- Headless Chromium checks at 1024x768 and 393x852 found no horizontal overflow.
  A synthetic conversation rendered text safely without interpreting HTML,
  thread selection called the native bridge, and Refresh became available.
  These checks do not establish iOS 10 WebKit compatibility.
- T3 Code's simulator device integration could not communicate with device
  support in this session, so no simulator runtime result is claimed.
- A separate private IPA with a one-use pairing credential was installed over
  Wi-Fi on the iPad4,5 running iOS 10.3.3. Installer reported Complete;
  querying installed `com.local.t3mini` returned version 0.1.0.
- User then confirmed that threads and conversations work on the iPad. This
  verifies launch, pairing, thread listing, and conversation reading on iOS 10.
  Relaunch persistence, scrolling performance, rotation, and wake behavior remain
  user checks in DEVICE_CHECKLIST.md.

The Mac's temporary HTTP adapter must remain running on the trusted LAN during
this test. Public artifacts contain no configured host or pairing credential.
