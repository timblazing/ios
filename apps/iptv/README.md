# TV

A live TV player for a [Dispatcharr](https://github.com/Dispatcharr/Dispatcharr) server on the home network, for the iPad mini 2 (iOS 10.3.3). Objective-C and UIKit. Prototype.

**Release:** [IPTV-0.2.0.ipa](dist/IPTV-0.2.0.ipa), the Debian package in `packages/`, and [checksums](dist/SHA256SUMS).

## Use

On first launch, enter the Dispatcharr base URL (for example `http://192.168.1.x:9191`). It's stored on the iPad only; the **Server** button changes it. The app loads `<base>/output/m3u` and lists the channels by group. Tap one to play it.

## How it works

AVPlayer only plays live video as HLS, and Dispatcharr's channel URLs (`/proxy/ts/stream/<id>`) are raw MPEG-TS. So the app repackages on the device, without transcoding:

1. `IPTVRelay` streams the channel's TS over HTTP.
2. `IPTVSegmenter` cuts it at H.264 keyframes into segments of at least 2 s, each starting with the PAT and PMT, and keeps the last 8 in memory (24 MB cap).
3. `IPTVLocalServer` serves `/live.m3u8` and `/seg/<n>.ts` on `127.0.0.1`, and AVPlayer plays that, decoding in hardware.

Dispatcharr sends a burst of about 30 s of buffered video on connect. The relay waits for segments to arrive in real time before publishing the playlist, and the player starts 5 s behind the newest segment. Expect a 6–7 s wait before playback and a picture that runs several seconds behind the source.

## Supported streams

The A7 decodes H.264 up to 1080p60 (High profile, level 4.2), with AAC audio. Channels in other video codecs, like 4K HEVC (H.265), can't play on this iPad: the app detects the codec from the stream's PMT and says so instead of spinning. To watch such a channel, give it a Dispatcharr ffmpeg stream profile that transcodes to H.264, for example:

```
-c:v libx264 -preset veryfast -vf scale=-2:720 -r 30 -b:v 4M -c:a aac -ac 2
```

That makes the server decode 4K live, and the same profile is the fallback if a 1080p60 channel stutters.

## Build and test

```sh
export THEOS=~/theos
make package FINALPACKAGE=1 -j4   # .deb in packages/
scripts/package-ipa.sh            # .ipa in dist/
scripts/test-stream.sh            # M3U parsing, segmentation, HEVC rejection (needs ffmpeg with libx265)
scripts/test-live.sh <stream-url> # end to end on the Mac: relay a live channel, read it with ffprobe and ffmpeg
```

`test-stream.sh` also runs `/tmp/espn.ts` if present (any real channel capture, `curl -m 10 -o /tmp/espn.ts <stream-url>`).

## Code

- `Application/Stream/`: Foundation-only, compiled for macOS by `scripts/build-tests.sh`. `IPTVPlaylist` (M3U parsing and grouping), `IPTVSegmenter`, `IPTVLocalServer`, `IPTVRelay`.
- `Application/UI/`: `IPTVChannelListController` (server prompt, grouped channel table) and `IPTVPlayerController` (an `AVPlayerViewController` that owns the relay and stops it on close, failure, or backgrounding).

## Gateway and next steps

- `gateway/`: Python service on the home server that serves one `/guide.json` (Dispatcharr channels, EPG and ESPN scores, matched to games) plus small cached logos. See `gateway/README.md`.
- `docs/STREAMS.md`: stream path tests. Dispatcharr's own HLS output (`?output_format=hls`) plays in AVPlayer without the on-device relay, which the native build should adopt.
- `docs/design/browser-mock.html`: the guide and player design at iPad mini 2 size.
- `docs/NEXT.md`: plan for the native UIKit build of that design.

## Not yet

The new guide and player (see `docs/NEXT.md`), pull to refresh, and Dispatcharr authentication.
