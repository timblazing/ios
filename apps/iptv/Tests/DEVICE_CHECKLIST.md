# TV device checklist

Run on the iPad mini 2 with the Dispatcharr server reachable on the same network.

- [x] 720p H.264 channels play with decent quality (0.1.0: 1400, 1401, 1403).
- [ ] A 1080p60 channel plays without dropped frames or stutter over several minutes.
- [ ] A 4K HEVC channel shows "This channel uses HEVC (H.265) video…" within a few seconds, and OK returns to the list.
- [ ] Time from tap to picture is under about 10 s.
- [ ] Delay versus the same channel on another device is under about 15 s.
- [ ] Closing the player and opening another channel works repeatedly (ten switches).
- [ ] Rotating during playback keeps playing.
- [ ] Going to the home screen stops playback; reopening the channel works.
- [ ] 30 minutes of playback without the app being killed (memory) or drifting further behind live.
- [ ] Changing the server URL reloads the channel list; a wrong URL shows an error.

## Dispatcharr HLS (no relay)

- [ ] A channel's `…?output_format=hls` URL plays in AVPlayer on the iPad (open it in Safari as a quick check)
- [ ] Startup is under 3 s on a 24/7 channel (e.g. NFL NETWORK)
- [ ] After 2+ minutes in the background, returning re-requests the stream and plays
- [ ] 720p60 (NFL NETWORK) plays smoothly without dropped frames
