# Apps for iPad mini 2

Apps in [timblazing/ios](https://github.com/timblazing/ios) target the jailbroken iPad mini 2 on iOS 10.3.3. Non-game apps live in `apps/<name>/`, alongside `games/<name>/`. Each app is a self-contained Theos project using the same iOS 10 target and Objective-C conventions.

| App | Status |
|---|---|
| [Paint](paint/) | v2.0.0; source, IPA, and Debian packages |
| [TV](iptv/) | v0.3.2 native guide and player for a Dispatcharr server |
| [T3 Code](t3code/) | v0.3.1 T3 Code chat companion |

The root `install.sh` discovers both games and apps. Networking, build instructions, and device-test status are documented in each app's README.
