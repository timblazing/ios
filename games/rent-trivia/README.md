# Rent Trivia

A personal trivia game for *Rent* (2005) on the iPad mini 2 (iOS 10.3.3). Objective-C + UIKit.

The local build uses official film artwork (logo, stills, cast photos from TMDB) for personal use. That art is
excluded from the source tree: `art/source/`, `Resources/Media/`, and generated icons are gitignored. Packaged `.deb`/`.ipa` releases include the artwork but exclude private Jellyfin configuration.
To build it yourself, put your own images in `art/source/` (`logo.png`, `stills/<name>.jpg`, `cast/<character>.jpg`,
names as referenced in `Questions.json`). Without them the game still builds and runs, just without pictures.

**Release:** [RentTrivia-1.1.1.ipa](dist/RentTrivia-1.1.1.ipa), Debian package in `packages/`, and [checksums](dist/SHA256SUMS).

The movie stream needs `Resources/Jellyfin.plist` (gitignored, holds the API key). Copy `Jellyfin.example.plist` and fill it in.

- 82 questions in `Resources/Questions.json` (first answer is the correct one; `img` shows a framed photo, `bg` sets the backdrop).
- Rounds of 10 or 25; score is shown as minutes out of 525,600. Best scores are saved in `NSUserDefaults` (`best.10`, `best.25`).
- **Watch the Movie** streams the film from Jellyfin (`Resources/Jellyfin.plist`: server, item ID, API key). The source is HEVC 10-bit + EAC3,
  which the A7 can't decode, so Jellyfin transcodes to 720p H.264 High 4.1 + stereo AAC over HLS, with the English `.srt` as a WebVTT track.
  Jellyfin 12 rejects `?api_key=`, so the token goes in an `Authorization` header via `AVURLAssetHTTPHeaderFieldsKey`. Closing the player
  saves the resume point and DELETEs `/Videos/ActiveEncodings` to stop the transcode. Press and hold the tile to change the API key on the device.
- Art sources are in `art/source/`; `scripts/make-art.py` (run by `make`) renders `Resources/Media/` and the icon.

```sh
export THEOS=~/theos
make package FINALPACKAGE=1 -j4
scripts/package-ipa.sh
scripts/test-rules.sh
```

Simulator screenshots: launch with `SIMCTL_CHILD_RT_SCREEN=title|quiz:N|quiz:N!|results|cast|movie`.
