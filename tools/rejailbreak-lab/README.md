# Re-jailbreak experiments (no exploit code)

For iPad4,5 / iOS 10.3.3. These probes isolate two questions before involving the working TNS jailbreak. They do not modify boot files, install a bootstrap, run an exploit, contact a server, or change another app's preferences.

## Self-contained WebClip

```sh
python3 tools/rejailbreak-lab/build-webclip-probes.py --out /tmp/offline-probes-new
```

Creates two HTML pages, corresponding `.webclip/Info.plist` files, and single-WebClip `.mobileconfig` profiles with the entire page in a `data:` URL:

- `Offline probe small`: 32 embedded test bytes; tests whether the URL scheme and automatic page JavaScript work.
- `Offline probe large`: 548,984 embedded test bytes, exactly the size of the reviewed TNS payload; tests URL length, loading and buffer decoding without the exploit.

Both verify every byte after base64 decoding. A successful page shows `PASS`, the number of bytes, opening time, URL scheme, standalone state and the browser's online flag. The flag alone does not prove that the network is disabled. The generated page has **zero network resources** and no telemetry or result upload.

On 2026-10-30 these two uniquely named WebClip folders were added to `/var/mobile/Library/WebClips/` with mobile ownership, then `uicache` completed. The original TotallyNotSpyware clip was preserved. The owner subsequently reported that the small icon was missing. Directory presence plus successful `uicache` was insufficient evidence of icon registration; neither physical opening nor offline operation has passed. No icon has been opened by automation. The small and large URL strings are about 2 KB and 978 KB respectively. Generated artifacts live outside Git.

Test one step at a time:

1. Install the generated `small.mobileconfig` through Safari and Settings to let iOS register the shortcut. It contains only one removable WebClip, with no certificates, VPN, restrictions or MDM. The owner must confirm the Settings installation. Acceptance of a `data:` URL through this path is itself unverified. Then open **Offline probe small** and record PASS/error/blank/missing icon. Serve the profile only temporarily from a reachable Mac address, using content type `application/x-apple-aspen-config`; stop that task-owned server after acceptance.
2. Only if the small probe passes, open **Offline probe large**. Confirm `Verified 548984 embedded bytes`.
3. Only after both pass, disable Wi-Fi and cellular data, then reopen the small probe and confirm a fresh opening timestamp. Repeat for the large probe. These pages are harmless while already jailbroken.
4. Re-enable the network for further diagnostics. A successful `data:` WebClip proves a potential offline delivery vehicle; it does not establish TNS's JIT execution or native payload behavior in that context.
5. A later TNS experiment should retain the existing recovery icon, embed the pinned payload bytes, and attempt once per explicit opening. Upstream `window.fail()` reloads the page, so remove/replace that behavior before introducing an auto-start entry point; otherwise failure plus auto-start could create a retry loop. No such exploit page is installed by these scripts.

The WebClip folders can be removed by the owner through the normal Home Screen delete control. Do not remove or clear the existing TNS clip or Safari's website data as part of cleanup.

## Legacy VoIP launch canary

```sh
python3 tools/rejailbreak-lab/build-canary.py --out /tmp/launch-canary-new
```

Creates **two ad-hoc-signed IPAs**, with different bundle IDs:

- `com.local.launchcanary.modern`: modern linked-SDK metadata, control.
- `com.local.launchcanary.legacy`: identical source, with `LC_VERSION_MIN_IPHONEOS` reporting SDK 9.3. Deployment target remains iOS 10.0. Metadata is changed before signing.

Both request legacy VoIP keep-alive and log app lifecycle events, `kern.boottime`, app state and protected-data availability to `Documents/launches.txt`. A normal window displays the log, and file sharing is enabled for later extraction. Only this app's container is written. There is no network code, no audio playback, no shell command, no exploit and no ability to open TNS. Background time requested during launch ends after two seconds; the legacy keep-alive registration is left in place for the experiment. Remove the canary when finished.

The API is resolved dynamically with a selector-existence check because this is explicitly an experiment with a deprecated legacy API, including on systems where it may no longer exist. This is not a recommendation for production app background execution.

**These ad-hoc signatures do not permit a stock-boot test.** AppSync can permit installation while jailbroken, but cold-boot execution requires valid Apple signing and an unexpired profile matching the app ID, certificate/team and target iPad. Never treat “installed through AppSync” as satisfying that gate. No matching local profile was found in this session; the canaries were built but not installed. Do not replace another app's bundle ID or provisioning profile to get around this.

After obtaining suitable signing, re-sign each bundle and preserve/reinspect its SDK metadata. For each final IPA, validate its signature and profile, then inspect the extracted executable:

```sh
codesign --verify --strict /path/to/Payload/LaunchCanary.app
xcrun vtool -show-build /path/to/Payload/LaunchCanary.app/LaunchCanary
```

`codesign --verify` alone does not establish that the profile authorizes this iPad or remains valid. A final signing tool may alter metadata; inspect **its output**, not just the intermediate build.

A controlled physical test eventually launches each canary once and backgrounds it (do not force-quit), then cold-boots and performs the first unlock without tapping either icon. Read the launch logs afterward and distinguish a background entry from the later manual inspection launch using timestamps and boot IDs. Log absence before first unlock is inconclusive because container data protection may prevent writing. Keep the known TNS manual recovery route available. This step is pending, not performed.

If the legacy canary launches automatically and the control does not, the next separate question is whether that background execution can open the offline TNS WebClip, or instead needs an audited native TNS-compatible reactivation entry point. Safari opening restrictions, foreground/JIT requirements, signature renewal and tweak/bootstrap compatibility remain separate tests. Do not install ap0110 wholesale to answer them.

## Local evidence

2026-10-30:

- Read-only inspection of the original ap0110 1.1b4 IPA confirmed linked SDK 9.3 on its arm64 slice and `UIBackgroundModes` audio/voip. The downloaded jailbreak was never installed or executed.
- Both arm64 variants compiled against the repo's Theos SDK with no warnings; final deployment target 10.0. The modern SDK reports 16.4 in the linked binary; the legacy reports 9.3. This is metadata compatibility selection, not an actual iOS 9 SDK build.
- Both ad-hoc signatures verified and both IPAs contain one `Payload/LaunchCanary.app` with no AppleDouble entries.
- The large HTML page decoded and verified every test byte in desktop Chrome. Desktop 1440×900 and phone 393×852 screenshots were inspected with no clipping. This is not iOS 10 or WebClip acceptance.
- The iPad's existing TNS ApplicationCache was copied read-only including its WAL. Its stored payload is 548,984 bytes and matches the reviewed upstream payload, SHA-256 `398e6f2340e791c0fe73b8bc4c0c25cffcb019f23078b0e5e3940a8f66678cc8`. The cached compiled scripts also match. Its stored HTML includes the redirect inline, unlike the current upstream index. Thus the first report's missing-external-redirect concern does not describe the cached page actually on this iPad.
- No reboot, actual jailbreak execution, bootstrap replacement, signature bypass installation or stock executable modification was performed.

Primary research and ranked leads: [research report](../../docs/IPAD-REJAILBREAK-RESEARCH.md).
