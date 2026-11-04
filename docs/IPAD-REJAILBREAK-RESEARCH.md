# iPad mini 2 re-jailbreak research

Investigated 2026-10-30 for **iPad4,5, A7, iOS 10.3.3**, currently using TNS Sockport.

## Result after the deeper investigation

**There is a concrete post-boot automation lead: ap0110's legacy VoIP app-launch mechanism.** The first pass missed it and focused too narrowly on a fully untethered boot chain. ap0110 explicitly lists iPad mini 2 and reports iPhone 5s / iOS 10.3.3 testing, the same A7/OS pairing. We should test its launch trigger independently of its jailbreak/bootstrap code.

Two useful offline leads are also concrete: the current iPad already has TNS's payload and scripts in its WebClip ApplicationCache, and a self-contained `data:` WebClip could remove cache/server dependence entirely. Harmless small and payload-sized WebClip probes have been copied to the device for physical acceptance. A pair of native launch canaries has been built, with stock-boot testing gated on valid signing.

The existing manual recovery route remains **unlock → open TotallyNotSpyware → slide**. There is no need to replace that route to test these hypotheses. No cold boot or actual exploit was performed during either research pass. See [the lab and test steps](../tools/rejailbreak-lab/README.md).

### Ranked leads worth pursuing

1. **Legacy VoIP auto-launch, then recovery.** [ap0110's source](https://github.com/athenusdev/ap0110/tree/2b2f4a21993f696df7c820708365001dcc38a3b4) declares `UIBackgroundModes` audio/voip, calls its routine from `didFinishLaunchingWithOptions:`, requests background time and then runs its exploit. Read-only inspection of the published [1.1b4 IPA](https://github.com/athenusdev/ap0110/releases/tag/1.1b4) also confirmed that its arm64 slice reports linked SDK 9.3 and declares audio/voip modes. Its [device/test list](https://github.com/ap0110site/ap0110site.github.io/blob/82121912e542a479ff5c078d45e1ce46eb5c1113/README.md) is directly relevant to this iPad. [Apple QA1938](https://developer.apple.com/library/archive/qa/qa1938/_index.html) confirms that iOS 10 retains old VoIP behavior for old-linked SDK apps and disables it for iOS 10 SDK builds. This is app execution after stock boot, not an iBoot untether. A valid Apple app signature/profile remains necessary. **Experiment prepared:** otherwise identical harmless loggers with modern versus SDK-9.3 metadata; no exploit, native launch, or reboot tested yet.
2. **Use the already-cached TNS clip offline.** Read-only inspection found its complete 548,984-byte payload with an exact upstream match, along with matching compiled scripts. Its cached HTML inlines the redirect code. This materially strengthens offline feasibility compared with merely inspecting the current upstream manifest. **Next experiment:** disable all iPad network access, open the existing TNS icon, inspect that the page renders, and stop before sliding while already jailbroken. Successful rendering alone would not prove offline re-jailbreaking; the later cold-boot exploit needs its own acceptance.
3. **A self-contained, auto-start WebClip.** Put all HTML/JavaScript and payload bytes in a `data:` URL stored in the WebClip's on-disk plist. If accepted by iOS 10, this uses Apple's existing signed web-app host and needs neither a new IPA signature nor a network resource/AppCache hit. This is a proposed delivery technique, not a demonstrated TNS capability. **Experiment installed:** a 32-byte probe and a 548,984-byte dummy buffer probe. Desktop decoding passes. The owner has now confirmed the small profile-installed WebClip opens and runs JavaScript offline with a fresh timestamp; the large dummy URL has also passed online/offline with fresh timestamps. Actual TNS execution remains pending. Then test TNS's JIT requirements separately.
4. **Reuse the VoIP trigger with a small native recovery helper.** If the signed canary proves launch after first unlock, test whether it can open the offline TNS clip from the background. If iOS blocks that or the WebKit context is unsuitable, evaluate a minimal audited native reactivation entry point that preserves TNS's existing bootstrap. Neither opening Safari from background nor native bootstrap compatibility follows automatically from the canary. A published [Amethyst experiment](https://github.com/uzmanwebmaster/amethyst-auto-rejailbreak/blob/8b2a45b566335f7ea9a8a8459e45f4bc18911f65/docs/HOW-IT-WORKS.md) demonstrates the linked-SDK metadata technique on iPhone 6 / iOS 12.5.8, including synchronous registration, first-unlock handling and boot-ID guards. That is useful implementation evidence, not acceptance on this iPad.

A later auto-start TNS wrapper must replace the upstream `fail()` implementation, which reloads the page. Otherwise an exploit failure could reload an auto-start page and create a retry loop. The harmless probes include no upstream exploit code at all.

### Filesystem-trigger hypothesis

Writing a file is a viable *configuration/storage* mechanism when an already-trusted stock component consumes it: the new WebClip plist is an example. It does not by itself establish a boot launch trigger or grant native executable trust. The VoIP experiment supplies a specific stock launch mechanism to test rather than assuming a new shell script will run.

The native canary avoids changing Apple's signed executables, launchd configuration, trust caches, or the current jailbreak. Single App Mode is another stock launch mechanism ([Apple AppLock documentation](https://developer.apple.com/documentation/devicemanagement/applock)), but supervision, kiosk lock-in and removal must be understood first. Do not prepare/erase the iPad or modify its supervision state just to test it.

## What a cold boot changes

TNS is a browser-delivered exploit chain: WebKit → kernel exploit → doubleH3lix post-exploitation → jailbreak services/userspace restart. The kernel patches are not persistent boot modifications. Installed packages and preferences can remain on disk while their jailbreak functionality is inactive.

The upstream code starts jailbreak launch daemons and SSH **after** kernel exploitation. Consequently, the currently working SSH connection is not an established way to re-jailbreak a stock cold boot. USB pairing/usbmux access and an SSH shell are separate capabilities. A port forward does not start an absent SSH server.

Activator is installed, but using it to open Safari at startup would depend on its jailbreak injection working first. An ordinary unsigned LaunchDaemon has the same bootstrap problem. AppSync is implemented with Substrate hooks; an AppSync-installed jailbreak app cannot be assumed to launch with stock signature enforcement after reboot. These are source-based conclusions, not cold-boot tests on this iPad.

## Routes and requirements

| Route | Interaction after cold boot | Mac / USB | Network | Finding |
| --- | --- | --- | --- | --- |
| Existing TNS Home Screen icon | Unlock if needed, open icon, slide; handle failures/retries | Neither required | Website reachable, normally Wi-Fi | Established upstream method; existing icon verified read-only |
| Cached TNS icon | Same interaction | Neither if cache works | Potentially none | Matching cached payload/scripts verified; physical offline operation pending |
| Custom auto-start TNS page | Unlock and open page/icon; potentially no slider | Neither at runtime if hosted/cached independently | Hosting or verified offline cache | Best scoped lead; mock test only |
| Legacy VoIP native helper | Potentially first unlock only | Signing/setup may need a computer; runtime potentially independent | Runtime potentially offline; signing renewal separate | ap0110 source lead; harmless canaries built, stock-boot test pending valid signing |
| Activator / SSH / added launch daemon | Cannot assume any can run before jailbreak activation | USB does not fix the missing bootstrap | Wi-Fi does not fix it either | Not a demonstrated cold-boot solution |
| Signed doubleH3lix / sockH3lix IPA | Launch app and use its jailbreak button | Computer/signing setup may be needed; renewal depends on signing method | Potentially offline while signature remains valid | Adds signing maintenance; no demonstrated boot automation |
| checkm8 / custom boot research | DFU/boot workflow, tool-specific | Host and USB for exploit delivery | Not a Wi-Fi boot exploit | Hardware exploit is not a ready-made iOS 10 jailbreak |

Do not substitute a full reboot for a respring casually. A normal respring does not itself boot a new kernel, but this session did not validate any new restart command or tweak combination.

## TNS source findings

Reviewed [LukeZGD/tns-sockport](https://github.com/LukeZGD/tns-sockport) at commit [`1ab104d48df7064cba3ea2f7650ae1e3e31c29be`](https://github.com/LukeZGD/tns-sockport/tree/1ab104d48df7064cba3ea2f7650ae1e3e31c29be), including its pinned doubleH3lix dependency `8b8159333c6be3d9c350c3db3c2f40d23634fe08`.

- [`root/js/slider.js`](https://github.com/LukeZGD/tns-sockport/blob/1ab104d48df7064cba3ea2f7650ae1e3e31c29be/root/js/slider.js): reaching 90% invokes a one-shot callback, then `window.go()` after 10 ms. The wrapper has no `isTrusted` check. Merely loading the stock page does not call it. A separate opt-in entry point could call the same function after readiness checks, with one attempt per opening and no automatic retry loop.
- [`index.html`](https://github.com/LukeZGD/tns-sockport/blob/1ab104d48df7064cba3ea2f7650ae1e3e31c29be/index.html): declares Apple standalone web-app metadata and `manifest.appcache`. A WebClip avoids IPA signing, but is not a boot launch mechanism.
- [`manifest.appcache`](https://github.com/LukeZGD/tns-sockport/blob/1ab104d48df7064cba3ea2f7650ae1e3e31c29be/manifest.appcache): caches page assets and `payload`, but omits `tns-redirect.js`, which the page loads. This omission does not prove that the remaining exploit cannot work offline; it means the manifest alone is insufficient evidence of complete offline operation. Cache eviction, standalone behavior and payload loading need physical testing.
- [`root/js/pwn.js`](https://github.com/LukeZGD/tns-sockport/blob/1ab104d48df7064cba3ea2f7650ae1e3e31c29be/root/js/pwn.js): `go()` retrieves the relative `payload` with XMLHttpRequest. A locally installed web server that itself needs the jailbreak would not solve cold-boot availability. Serving the exploit with `file://` or inside a new WKWebView wrapper is also not established by this research.
- [`glue/src/main.mm`](https://github.com/LukeZGD/tns-sockport/blob/1ab104d48df7064cba3ea2f7650ae1e3e31c29be/glue/src/main.mm): calls the kernel exploit before doubleH3lix and `runLaunchDaemons()`. Its kernel-success popup has a five-second timeout; it is not necessarily a required acknowledgement on each run.
- [`glue/jailbreak.patch`](https://github.com/LukeZGD/tns-sockport/blob/1ab104d48df7064cba3ea2f7650ae1e3e31c29be/glue/jailbreak.patch) and [pinned doubleH3lix post-exploitation](https://github.com/Siguza/doubleH3lix/blob/8b8159333c6be3d9c350c3db3c2f40d23634fe08/doubleH3lix/jailbreak.mm): bootstrap installation is conditional; missing bootstrap files can require a download and an installation confirmation. Preserve the existing dpkg/bootstrap markers. Do not describe every recovery path as one tap.

The repo ships a prebuilt payload. This session inspected source and dependencies; it did not rebuild the payload or establish reproducible binary/source equivalence.

## Alternatives checked

- [LukeZGD Legacy iOS Kit jailbreaking guide](https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Jailbreaking) identifies TNS for **64-bit iOS 10.0–10.3.3**, using Safari without sideloading. Its ramdisk/custom-IPSW jailbreak methods are described as **32-bit only**; A7 downgrade support does not imply a persistent A7 jailbreak.
- [sockH3lix](https://github.com/SongXiaoXi/sockH3lix) targets iOS 10 64-bit devices and states compatibility with doubleH3lix. Its `ViewController.m` runs the jailbreak from a button action, not automatically from `viewDidLoad`. Upstream compatibility is not a guarantee about every tweak or the current TNS bootstrap; switching was not tested.
- [Socket](https://github.com/staturnzz/socket) is for **32-bit** devices. Do not confuse the iPad mini 2 with the iPad 4 or infer applicability from an iOS 10 version match.
- [p0insettia plus](https://github.com/LukeZGD/p0insettia-plus) supports **iPhone 5 on 10.3.4**; its untether requires device-specific iOS 7.1.x blobs. It is not an iPad4,5 untether.
- [checkra1n](https://checkra.in/) supports **iOS 12 and later**. Its A7 hardware support does not make it a drop-in jailbreak for 10.3.3. No DFU, restore, downgrade or boot-chain experiments were performed.
- [AppSync Unified](https://github.com/akemin-dayo/AppSync#im-a-developer--do-you-have-a-rough-high-level-explanation-as-to-how-this-all-works) documents Substrate-based signature-validation hooks. It is not a persistent stock-boot signing solution.

## Evidence from the first pass

- Read-only USB queries confirmed `iPad4,5`, `10.3.3`, and the installed user-app list.
- USB SSH with the existing key worked. Initial uptime was about 18 hours 52 minutes; no reboot was requested or performed.
- Package inventory included AppSync Unified 116.1, Activator 1.9.13, Cydia Substrate 0.9.7020 and OpenSSH 8.4 packages.
- The existing `TotallyNotSpyware` WebClip points to `https://lukezgd.github.io/tns-sockport/`. No new icon was needed to reach the stock method.
- Saved a private Mac-side snapshot of dpkg status, launch-daemon definitions, Substrate tweak files, mobile preferences and WebClips. Archive creation succeeded and all 459 entries were read successfully. **This is not a full device backup, a complete reinstallable package archive, or a tested restoration procedure.** It remains outside Git, under the owner's private local state directory.
- A Node JavaScript harness evaluated only upstream `slider.js`, with a mocked `go()`. Page load made zero calls; the slider made one call and did not repeat on a second mouse-up; a direct call worked without a trusted touch. No WebKit or kernel exploit code ran. This proves wrapper behavior only.
- T3 Device panel discovery exposed simulators only, not the physical iOS 10 iPad. No screen automation was attempted or bypassed over SSH.
- During the first pass, no app installation, jailbreak execution, respring, reboot, package change, boot-file change, preference edit or icon edit was performed. Task-owned USB forwarding was stopped afterward.

## Current checkpoint

**Both small and payload-sized WebClips passed physical offline opening.** Folder copying plus `uicache` did not produce a visible small icon, but installing the profiles through Safari/Settings did. The owner reported PASS with fresh timestamps for both probes online and offline. This verifies self-contained data-URL pages running JavaScript and decoding a payload-sized buffer on this iPad; it does not establish TNS JIT/exploit execution or cold-boot recovery.

The lab now builds a hash-pinned **TNS Offline Check** profile and a separate, manually triggered **Offline TNS** candidate. The check-only page validates the actual embedded payload and script parsing, and reports the renderer/target match without calling the exploit. The live candidate does not auto-start or reload on failure; a manual run button avoids automatic retry after WebKit reloads. The owner confirmed the check-only profile passes on the physical iPad online and offline: 548,984 payload bytes verified, TNS scripts parsed, renderer `Apple A7 GPU`, and target match `true`. This proves packaging/decoding and script parsing, not JIT exploitation. The live candidate was not served or installed. The owner deferred its actual exploit test to focus the next agent on legacy VoIP. The temporary profile server has been stopped. No actual exploit, reboot or bootstrap change has been performed.

Native VoIP canaries remain pending valid Apple provisioning/signing. Detailed per-step acceptance and cleanup live in [the lab README](../tools/rejailbreak-lab/README.md).

The next agent should start with [the ap0110 legacy-VoIP handoff](AP0110-VOIP-HANDOFF.md).
