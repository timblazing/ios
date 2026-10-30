# iPad mini 2 re-jailbreak research

Investigated 2026-10-30 for **iPad4,5, A7, iOS 10.3.3**, currently using TNS Sockport.

## Result

No supported fully automatic cold-boot jailbreak was found for this exact device/OS. This is a bounded research finding, not proof that a future or experimental untether is impossible.

The practical route remains **unlock → open the existing TotallyNotSpyware Home Screen icon → slide → let TNS reactivate the jailbreak**. It does not require a Mac, USB, sideloading or an Apple signing certificate. Online use needs the iPad to reach the public website, normally over Wi-Fi. The actual cold-boot sequence was not repeated in this session.

The best development lead is a **separate, opt-in TNS page that starts after opening**, removing the slider. Source inspection and a mocked JavaScript test support this lead; actual iOS 10 exploit execution, offline operation and preservation across a cold boot remain unverified. This would reduce interaction, not make the jailbreak run automatically at power-on.

## What a cold boot changes

TNS is a browser-delivered exploit chain: WebKit → kernel exploit → doubleH3lix post-exploitation → jailbreak services/userspace restart. The kernel patches are not persistent boot modifications. Installed packages and preferences can remain on disk while their jailbreak functionality is inactive.

The upstream code starts jailbreak launch daemons and SSH **after** kernel exploitation. Consequently, the currently working SSH connection is not an established way to re-jailbreak a stock cold boot. USB pairing/usbmux access and an SSH shell are separate capabilities. A port forward does not start an absent SSH server.

Activator is installed, but using it to open Safari at startup would depend on its jailbreak injection working first. An ordinary unsigned LaunchDaemon has the same bootstrap problem. AppSync is implemented with Substrate hooks; an AppSync-installed jailbreak app cannot be assumed to launch with stock signature enforcement after reboot. These are source-based conclusions, not cold-boot tests on this iPad.

## Routes and requirements

| Route | Interaction after cold boot | Mac / USB | Network | Finding |
| --- | --- | --- | --- | --- |
| Existing TNS Home Screen icon | Unlock if needed, open icon, slide; handle failures/retries | Neither required | Website reachable, normally Wi-Fi | Established upstream method; existing icon verified read-only |
| Cached TNS icon | Same interaction | Neither if cache works | Potentially none | Manifest exists, but offline device operation unverified |
| Custom auto-start TNS page | Unlock and open page/icon; potentially no slider | Neither at runtime if hosted/cached independently | Hosting or verified offline cache | Best scoped lead; mock test only |
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

## Evidence from this session

- Read-only USB queries confirmed `iPad4,5`, `10.3.3`, and the installed user-app list.
- USB SSH with the existing key worked. Initial uptime was about 18 hours 52 minutes; no reboot was requested or performed.
- Package inventory included AppSync Unified 116.1, Activator 1.9.13, Cydia Substrate 0.9.7020 and OpenSSH 8.4 packages.
- The existing `TotallyNotSpyware` WebClip points to `https://lukezgd.github.io/tns-sockport/`. No new icon was needed to reach the stock method.
- Saved a private Mac-side snapshot of dpkg status, launch-daemon definitions, Substrate tweak files, mobile preferences and WebClips. Archive creation succeeded and all 459 entries were read successfully. **This is not a full device backup, a complete reinstallable package archive, or a tested restoration procedure.** It remains outside Git, under the owner's private local state directory.
- A Node JavaScript harness evaluated only upstream `slider.js`, with a mocked `go()`. Page load made zero calls; the slider made one call and did not repeat on a second mouse-up; a direct call worked without a trusted touch. No WebKit or kernel exploit code ran. This proves wrapper behavior only.
- T3 Device panel discovery exposed simulators only, not the physical iOS 10 iPad. No screen automation was attempted or bypassed over SSH.
- No app installation, jailbreak execution, respring, reboot, package change, boot-file change, preference edit or icon edit was performed. Task-owned USB forwarding was stopped afterward.

## Next bounded experiment

1. Keep the current stock TNS icon as the recovery route. Retain private backups and capture any additional package installation archives needed before exploit testing.
2. Prepare a separate, opt-in page based on the pinned TNS assets. First use a harmless stub in place of the exploit to test Home Screen launch, load-once behavior and iOS 10 offline caching. Use a distinct icon/origin and an explicit ready indicator; preserve the stock page and its cache. Serve staging assets independently of the iPad's jailbreak services.
3. With the owner handling the screen, test the harmless page online and then with network access disabled **without rebooting**. Resolve the missing cache dependency and verify every requested resource rather than assuming the manifest works.
4. Only after that passes, test the actual exploit from a normal unjailbroken boot with the owner available to unlock and recover through the stock TNS icon. Record attempts, extra prompts, successful tweak reactivation and USB/Wi-Fi independence separately. Do not run the exploit again just to test while already jailbroken.
5. Call it one-tap re-jailbreaking only after that physical acceptance passes. Automatic operation immediately after cold boot remains a separate, unresolved problem.
