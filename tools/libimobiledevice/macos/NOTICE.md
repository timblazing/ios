# Bundled libimobiledevice tools

`install.sh` uses these prebuilt universal (arm64 + x86_64) macOS binaries, copied unmodified from [Legacy iOS Kit](https://github.com/LukeZGD/Legacy-iOS-Kit) `bin/macos/`. They are bundled so installing needs nothing from Homebrew. They also come from Legacy iOS Kit's libimobiledevice fork, which is known to work with iOS 10.

| File | Project | License |
|---|---|---|
| `ideviceinstaller` | [ideviceinstaller](https://github.com/libimobiledevice/ideviceinstaller) 1.2.0 | GPL-2.0 |
| `idevicepair`, `ideviceinfo`, `lib/libimobiledevice-1.0.6.dylib` | [libimobiledevice](https://github.com/LukeZGD/libimobiledevice) (LukeZGD fork) | LGPL-2.1 (tools: GPL-2.0) |
| `lib/libusbmuxd-2.0.7.dylib` | [libusbmuxd](https://github.com/libimobiledevice/libusbmuxd) | LGPL-2.1 |
| `lib/libimobiledevice-glue-1.0.0.dylib` | [libimobiledevice-glue](https://github.com/libimobiledevice/libimobiledevice-glue) | LGPL-2.1 |
| `lib/libplist-2.0.4.dylib` | [libplist](https://github.com/libimobiledevice/libplist) | LGPL-2.1 |

Source code is available at the links above. The binaries load their libraries from `@executable_path/lib`, so keep the layout as is.
