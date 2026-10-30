# ap0110 legacy VoIP: next-agent handoff

Checkpoint: 2026-10-30. Goal: make re-jailbreaking after restart automatic, or reduce it to the first unlock, on **iPad mini 2 / iPad4,5 / A7 / iOS 10.3.3**, preserving the existing TNS Sockport bootstrap, tweaks, pairing and user data.

## Start here

Read root `AGENTS.md`, [the research report](IPAD-REJAILBREAK-RESEARCH.md), and [the lab README](../tools/rejailbreak-lab/README.md). Inspect Git/worktree/PR state before edits; the current work was pushed on `docs/t3-device-panel`, [PR #6](https://github.com/timblazing/ios-games/pull/6), left open and unmerged. Recheck this rather than assuming it remains current.

The user authorizes implementation and staged jailbreak/device testing, but preserving the iPad and its tweaks is a binding constraint. They want creative, source-driven experiments and a working result, not another conclusion based solely on community compatibility lists. Work toward actual automatic post-boot recovery. Use harmless tests to separate launch behavior, signing, execution context and bootstrap compatibility.

## Concrete mechanism, not a generic untether search

- [ap0110 source](https://github.com/athenusdev/ap0110), inspected at `2b2f4a21993f696df7c820708365001dcc38a3b4`. `Athenus/Info.plist` has `UIBackgroundModes` audio/voip; `AppDelegate.m` calls `fun()` during launch; `untethered.m` requests background execution and calls its native jailbreak when Cydia exists.
- [ap0110 website source](https://github.com/ap0110site/ap0110site.github.io/blob/82121912e542a479ff5c078d45e1ce46eb5c1113/README.md) lists iPad mini 2 and reports iPhone 5s on 10.3.3 working, the same A7/OS combination. It credits spacepilotAV's voip_load/Athenus autoexecution.
- Read-only inspection of [ap0110 1.1b4](https://github.com/athenusdev/ap0110/releases/tag/1.1b4) confirmed SDK **9.3** and minimum **8.0** in its arm64 Mach-O, plus audio/voip modes. It was never installed or run.
- [Apple QA1938](https://developer.apple.com/library/archive/qa/qa1938/_index.html) says iOS 10 retains legacy VoIP behavior for apps linked with an old SDK, but disables it for iOS 10 SDK builds. Merely lowering the deployment target is insufficient.
- [Amethyst auto-rejailbreak experiment](https://github.com/uzmanwebmaster/amethyst-auto-rejailbreak/blob/8b2a45b566335f7ea9a8a8459e45f4bc18911f65/docs/HOW-IT-WORKS.md) demonstrates changing SDK metadata before signing, synchronous legacy keep-alive registration, first-unlock handling and boot-ID guarding. Its reported acceptance is iPhone 6 / iOS 12.5.8, not our iPad.

This is a stock-iOS app-launch path, not an iBoot untether. Native executable trust, post-boot launch, first unlock, running an exploit in the resulting context, and restoring the current jailbreak are distinct gates.

## Prepared code

`tools/rejailbreak-lab/LaunchCanary.m` and `build-canary.py` build harmless arm64 launch loggers with distinct bundle IDs:

- `com.local.launchcanary.modern`: modern linked SDK (reports 16.4 with the installed Theos SDK).
- `com.local.launchcanary.legacy`: linked-SDK metadata 9.3, minimum 10.0; this differs from original ap0110's minimum 8.0 and the newer Amethyst experiment's minimum 9.0, so examine that variable if results differ.

Both compile warning-free, record lifecycle events/boot ID/app state/protected-data state to their Documents log, and request legacy keep-alive. Neither contains exploit/network code, executes a command, opens TNS, or writes outside its container. Their **ad-hoc** signatures validate locally but do not establish stock-boot execution. Neither canary was installed.

A local development signing identity existed, but no matching app/device provisioning profile was found. Recheck current signing and device enrollment. Do not repurpose the unrelated app's profile/identity or assume AppSync substitutes for a valid Apple signature after reboot. Get a suitable profile and sign the final artifact; inspect SDK metadata after the final signing tool, because it may rewrite it. Do not change metadata after signing without signing again. Use the client's private secret mechanism if credentials are needed; never put them in chat, code, logs or Git.

## What has actually passed on the iPad

- Small and payload-sized self-contained `data:` WebClips installed through Safari/Settings configuration profiles.
- Both run JavaScript and decode embedded bytes with fresh timestamps online and offline, reported by the owner. The large buffer is **548,984 bytes**, matching TNS's native payload size.
- **TNS Offline Check** also passes physically online and offline: actual payload verified, real TNS scripts parsed, `Renderer: Apple A7 GPU`, target iPad / iOS 10.3.3 / A7 = `true`. This does not establish JIT/exploit execution.
- The iPad's existing TNS WebClip ApplicationCache contained the identical upstream native payload, SHA-256 `398e6f2340e791c0fe73b8bc4c0c25cffcb019f23078b0e5e3940a8f66678cc8`.

`build-offline-tns.py` can reproduce that check profile and a separate manually triggered live candidate from pinned upstream files. The native payload and `pwn()` are unchanged; it removes the payload-fetch adapter and replaces failure reloads with stopping errors. The live candidate is **not auto-starting**, was not served/installed/run, and is not a proven offline fallback. The owner deferred this test to prioritize VoIP.

## Device and cleanup state

No actual exploit, reboot, bootstrap replacement, native canary installation, boot-file change or signed stock-binary edit was performed. Existing TNS/tweaks were preserved. Installed small/large/check configuration profiles and test icons were left in place. Manually copied probe folders also remain; do not confuse them with OS-registered profile WebClips.

The original **TotallyNotSpyware** recovery icon remains. Preserve it and its cache. Do not clear Safari website data or remove the bootstrap. Before any reboot, confirm a known manual recovery route is usable; do not rely solely on the untested new live candidate.

Private inventory, preference/tweak/package-state archive and TNS cache snapshot are under `~/.local/state/ios-games/jailbreak-research-2026-10-30/`. The 459-entry archive was read successfully; it is not a complete device backup or a tested restoration. It does not contain a full reinstallable copy of every package. Preserve it and consider additional recovery material before riskier tests.

Temporary HTTP profile server and task-owned SSH/USB forwarding were stopped. No test server should be assumed running. USB was not detected during recent discovery; paired Wi-Fi access worked while the iPad was awake/unlocked and connected. Identify the device explicitly: the owner's iPhone may also appear. The iPad was last asked to disable networking for the offline check; ask the owner to re-enable it for discovery/installation when needed.

Sources/generated artifacts were under `/tmp/ios10-ap0110-trigger-research`, `/tmp/ios10-ap0110-release-inspection`, `/tmp/ios10-tns-research`, `/tmp/ios10-launch-canary-20261030-v3`, `/tmp/ios10-offline-profile-probes-20261030`, `/tmp/ios10-tns-offline-check-20261030-v2`, and `/tmp/ios10-tns-offline-live-20261030-v2`. Treat scratch artifacts as disposable; source scripts/pins in Git are authoritative. Keep generated native payloads and private device artifacts outside Git.

## Next sequence and completion criteria

1. Resolve valid signing and build a minimally changed legacy canary plus control. Ensure logging distinguishes automatic background launch from manually opening the app to inspect it. File protection can hide pre-unlock events; absent logs alone are inconclusive.
2. Install/launch/background the harmless canaries, then conduct an owner-driven reboot/first-unlock test. Capture logs and boot IDs without tapping the canaries first. Determine whether networking, USB, foreground state or prior force-quit affects the result. Record actual dependencies, not assumptions.
3. If automatic launch works, choose and test a TNS-compatible recovery path. Background opening of a WebClip may be restricted; embedding a WKWebView may lack the necessary JIT behavior; native reactivation must preserve the current bootstrap. Research/test those separately. **Do not install ap0110 wholesale over TNS to skip compatibility work.**
4. Before any automatic exploit, implement and verify a persistent disarm/attempt-budget mechanism that is consumed before execution and survives both process crashes and device reboots, with a proven manual recovery/disable path. A per-boot guard alone can still create repeated panic/reboot attempts across boots. Wait for first unlock/protected data and avoid concurrent or already-jailbroken attempts. No unattended retry loops.
5. Prove the resulting behavior on this physical iPad, including tweak reactivation, before calling it complete. Document signing expiry/renewal and offline/USB dependencies honestly. Commit/push and update/create the PR through repo workflow; do not merge unless requested.

Use the Device panel if it exposes this physical device; it previously listed simulators only. Otherwise let the owner handle screen actions, one interaction at a time. Follow the root device-tool rules; do not silently drive the screen over SSH. Builds, installs and read-only diagnostics can use supported CLIs. Never start Docker/a local VM on this Mac.

## Signing follow-up checkpoint — 2026-10-30

Repository inspection found a clean `docs/t3-device-panel` checkout at `9d7d865`, matching open/unmerged PR #6; no other worktree. Paired Wi-Fi discovery again reports `iPad4,5` / `10.3.3`. Neither canary is installed. USB-only discovery did not find this iPad. The Device panel initially failed with “Could not communicate with device support. Try refreshing devices.” One refresh succeeded and exposed simulators only; physical screen actions remain owner-driven.

Xcode 27.2 has an existing Personal Team account session and a usable Apple Development identity. The pre-existing House Capture profile does not enroll this iPad and was not reused or changed. Xcode obtained separate profiles for the exact legacy/modern canary bundle IDs. Both authorize the available signing certificate, but **neither profile enrolls the iPad yet**. UTC expiration: legacy `2026-11-06 20:32:57`, modern `2026-11-06 20:34:42`. Valid target signing remains unresolved; no stock-boot capability is claimed.

New `tools/rejailbreak-lab/sign-canary.py` validates exact canary app authorization, time window, target enrollment, certificate and team before signing a copy outside Git. It then checks the final Apple signature chain, entitlements, certificate and unchanged linked-SDK metadata and emits an IPA. Five local validation tests pass. A preflight with the actual legacy profile and private target UDID correctly rejects missing iPad enrollment before producing an artifact. A positive final signing/physical launch test remains pending.

Provisioning experiment scratch: `/tmp/ios10-canary-provision-20261030/`, including `project.yml`, generated Xcode project and build logs. `xcodegen` is available. This is a **profile acquisition helper**, not the canary: Xcode's installed SDK rejects an iOS 10 deployment target, so the helper build uses minimum iOS 15. The actual canaries continue using the repo's Theos SDK/iOS 10 builder. Never install the helper's build products. Its generic iOS build can obtain profiles without enrolling this iPad; a successful helper build therefore does not satisfy the signing gate.

Next physical interaction requested: connect the iPad mini 2 by USB, unlock it, leave it on Home Screen, and accept Trust if prompted. No reboot or canary opening requested. Await the owner's report, inspect USB/Xcode discovery, and enroll the actual target through the available signing workflow. If current Xcode cannot enroll iOS 10, resolve that concrete enrollment limitation rather than installing an AppSync/ad-hoc substitute. The private target UDID file is in the existing private state directory as `canary-target-udid.txt`; it must not enter Git or public logs.

No exploit execution, reboot, canary installation, attempt-budget implementation or automatic recovery test occurred in this follow-up. The original recovery icon/cache and bootstrap were not modified. Offline WebClip/full TNS check acceptance remains as recorded above; actual exploit execution remains untested. There is no task-owned server, forward or simulator to stop. Required later gates remain: target-valid signing, automatic legacy-versus-control post-boot launch, persistent crash/reboot-safe disarm/attempt budget and manual recovery proof, then TNS-compatible physical reactivation.
