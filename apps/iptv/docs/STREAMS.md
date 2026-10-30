# Stream path findings (2026-10-29)

Tested against the home Dispatcharr (v0.33.0) and the Xtream Codes provider behind it. The provider allows **2 concurrent streams**, so test one capture at a time.

## Recommendation

**Play Dispatcharr's HLS output directly in AVPlayer and retire the on-device relay** (`IPTVRelay`/`IPTVSegmenter`/`IPTVLocalServer`). Append `?output_format=hls` to the channel's stream URL (the gateway does this). Dispatcharr then redirects to `/proxy/hls/<token>/index.m3u8`.

Keep the relay code until the device checklist confirms HLS playback, then delete it.

## What was measured

| Path | Start | Segments | Notes |
|---|---|---|---|
| Dispatcharr `/proxy/ts/stream/<uuid>` (current app) | fast | n/a: raw TS, repackaged on the iPad | Needs the on-device relay. NFL Network: 720p60 H.264 High + HE-AAC, about 4.4 Mbps. The provider bursts about 25 s of media in the first seconds. |
| **Dispatcharr `?output_format=hls`** | **first playlist in about 2 s** | 2–4 s, keyframe-aligned, `#EXT-X-START:TIME-OFFSET=-5` | Packet copy, no transcode. Real-time paced. Stable media sequence. Shares the single provider connection with any other viewer of that channel. |
| Provider direct `.m3u8` | about 1 s | about 10 s | `EXT-X-MEDIA-SEQUENCE` went **backwards** between two polls (2901 → 2888), which looks like load-balanced origins out of sync. That stalls or confuses AVPlayer. 10 s segments also mean slower start and more latency. |
| Provider direct `.ts` | about 0.5 s (302 to a tokenized host) | n/a | Same as Dispatcharr TS but would put provider credentials on the iPad, and it skips Dispatcharr's connection sharing, so each device uses one of the 2 slots. |

Details:

- **Waiting comments.** The HLS playlist response starts with `# dispatcharr: waiting N` comment lines while the first segment is cut. These are legal HLS comments and AVPlayer ignores them.
- **Sessions expire.** The HLS session token expires about 60 s after the last request (`Session expired`/410). After a long pause or backgrounding, re-request the original `?output_format=hls` URL rather than reusing the token URL.
- **Pre-game event channels don't stream.** Before kickoff, the provider's event streams (`NCAAF 01: …`, NBA event channels) are a 15 s placeholder HLS clip with `#EXT-X-ENDLIST`. Dispatcharr tries 3 times, then marks the channel ERROR. The app should not try to play a game whose `state` is `pre` unless the user insists. Show the start time instead.
- **Relay pacing bug (only matters if the relay stays).** Unpaced input (placeholders arrive at about 60× real time) fills the 8-segment window faster than playback. The `IPTVBurstSettleLimit` path publishes anyway and the window races ahead of the player. The fix would be to pace intake by PTS. Dispatcharr HLS avoids this entirely.

## Codecs

The initial sports channels sampled were H.264 + AAC, which the A7 decodes in hardware: event placeholders (1080p30 Baseline) and NFL Network (720p60 High). Dispatcharr's HLS output is a packet copy, so HEVC channels would still not play. If one shows up, add a Dispatcharr stream profile with ffmpeg `-c:v libx264` for that channel only (raygun is 4-core ARM, so budget about one 720p transcode).

## Dispatcharr settings and plugins

- **Default Output Format:** leave it MPEG-TS for other clients. The app opts into HLS per request with `?output_format=hls`.
- **Stream profile:** keep the default proxy (no transcode).
- **EPG:** the Custom Dummy EPGs for NBA, NFL and NCAAF carry no game info, and the gateway replaces them with ESPN data. The provider's XMLTV ("Primary", about 4400 entries) is not mapped to any channel yet. Mapping it to the 24/7 network channels (ESPN, FS1, NFL NETWORK…) with **EPG Janitor** or **Channel Mapparr** (both installed) fills the tiles' now/next for free. The gateway passes the EPG through.
- **Worth trying:** *Event Channel Managarr*, to hide event channels without a current event, so the guide stays clean between weeks. *Underfed*, for source failover when a provider stream dies.
- **Skip:** delay-buffer and fallback-loop plugins. HLS already gives a small buffer, and a fallback loop would look "live" to the app when it isn't.

## 0.3.2 physical-failure follow-up

Owner-reported Panthers @ Packers and Troy @ James Madison failures were correlated with Dispatcharr upstreams ending and retrying. Later, with owner playback stopped, sequential bounded server captures found:

- NFL regular backup: eight seconds of real Panthers–Packers video, 1280×720 at 60000/1001 fps, H.264 Main + stereo HE-AAC, approximately 2.7 MB. Capture completed in 4.16 seconds; that is server capture elapsed time, not iPad tap-to-picture time.
- NFL primary: eight seconds, 3840×2160 at 60000/1001 fps, HEVC Main 10 + six-channel AC-3, approximately 18.8 MB. This is confirmed incompatible with the A7 target; the primary selection should be excluded for this client. No transcoding was enabled.
- NCAAF selected ESPN2 source: eight seconds of broadcast video, 1280×720 at 60000/1001 fps, H.264 Main + stereo HE-AAC, approximately 3.2 MB. It is delivering compatible media now; the earlier short-lived upstream failure remains unexplained and requires physical retest.

A first frame from the regular NFL capture shows the actual game. The NCAAF capture shows an ESPN2 studio segment; this verifies media delivery, not continuous correct-event coverage. Capture files were temporary and removed remotely; private first frames and sanitized probe summaries are saved outside Git. Closed each capture before the next and checked Dispatcharr client expiry between channels. After the final capture, a read-only Dispatcharr check confirmed zero active proxy clients before handback.

The gateway now supports a private `EXCLUDED_CHANNEL_NUMBERS` list, with regression coverage ensuring exclusions cannot leak into primary/backup feeds or tiles and that unrelated leagues remain present. A candidate using current data removes only the probe-confirmed incompatible NFL source and retains the compatible regular source. The owner approved this deployment/configuration; production verification confirms only the regular NFL feed remains for the matchup and all leagues stay populated. Physical NFL/NCAAF retests remain pending. Both original Dispatcharr channels are unchanged. No new iPad build is required for this guide change.
