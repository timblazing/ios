# v2 build verification

Built on 2026-10-02 on macOS with Theos, current Xcode, and the iPhoneOS 16.5 SDK (deployment target iOS 10.0).

- Release compilation, linking, ad-hoc signing, and Debian packaging completed with no compiler warnings. The linker notes that Theos's `-multiply_defined` flag is obsolete; that's harmless.
- `vtool -show-build` reports `LC_VERSION_MIN_IPHONEOS` version 10.0 (SDK 16.4 in the load command), ARM64.
- The binary's imported symbols are standard Objective-C runtime, UIKit, SpriteKit, CoreGraphics, and libc calls available on iOS 10.
- Rules tests pass on macOS:

```text
PASS: 153993 assertions; deal, stock/recycle, moves, flips, undo, persistence, stats, victory, auto-win, 2400 random steps.
```

- `scripts/make-icons.sh` was run against a test master; it wrote all seven sizes (29–167 px) and keeps the existing icons when the master is missing.
- The app was also compiled for the iOS simulator (iPad mini, current iOS) with a partial card art set. Portrait layout, the bottom controls bar, the drawn icons, and per-card art fallback rendered correctly. The simulator couldn't be rotated in this headless setup, so landscape and mid-game rotation are unverified there.
- The design playground was exercised in Chromium: card loading, validation, board, stress views, deck, icon validation (including transparency detection), size strip, home screen mock, and v1 comparison.

Not tested here: installation on iOS 10.3.3, rotation on device, and A7 frame rate. See DEVICE_CHECKLIST.md.

Package SHA-256 hashes are in `dist/SHA256SUMS`.
