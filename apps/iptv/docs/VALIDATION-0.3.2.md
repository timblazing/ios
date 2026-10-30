# TV 0.3.2 validation — 2026-10-29

TV 0.3.2 / build 5 is installed with owner approval; an independent installed-app query verifies version/build. Functional acceptance remains pending. No UI layout changes or new simulator evidence in this continuation.

## Gateway selection

Foundation-only `IPTVGuideClient` tries the private primary gateway first and the optional fallback second. HTTP failures, transport failures/timeouts and malformed guides advance to fallback. A 304 is accepted only with an existing guide and validator from that same endpoint. Each poll retries home. Successful selection supplies the guide, stream addresses and logo base together; exhausting routes preserves the last guide and its base. Cancellation on background/navigation prevents old requests from selecting a route after a new load.

`gateway.fallbackBaseURL` is privately provisioned like the existing primary. Profiles preserve omitted values, reject invalid fallback atomically and remove the fallback default for an explicit empty string. Candidate URLs are validated and deduplicated. Request timeout is four seconds; overall resource timeout is six seconds per route. This does not start or replace the Mac USB bridge, which must exist for offsite fallback.

## Automated/build checks

- `scripts/test-gateway.sh`: compiled Foundation client against a real loopback HTTP fixture. Passes home preference, same-route 304, primary HTTP failure, refused connection, fallback selection, correct stream origin, home recovery without cross-route validators, malformed guide, timeout, uncached 304 rejection, invalid URL skipping, all-unavailable last-good preservation, empty configuration and cancellation followed by fresh reload.
- `scripts/test-configuration.sh`: pass, including fallback normalization, atomic rejection and explicit clearing.
- `scripts/test-guide.sh`: pass.
- Theos arm64 release package builds; only the existing obsolete linker-flag warning. `vtool` confirms iOS 10.0 minimum.
- IPA integrity, bundle ID `com.local.iptv`, version 0.3.2/build 5, private-filename/macOS-metadata exclusions and all eight committed release checksums pass.

## Physical preparation and limits

With TV closed by the owner, verified home guide reachability from iPad4,5 / iOS 10.3.3. Backed up preferences privately and saved home-primary plus USB-fallback defaults through mobile preferences. Read back both values and verified every unrelated preference was preserved. No private profile exists to override them. No video stream was opened and no physical guide/UI/playback claim follows from the transport check.

Owner-approved USB installation passed after reverifying iPad4,5 / iOS 10.3.3 and the IPA checksum/identity/version/build (`Install: Complete`). Independent installed-app query confirms 0.3.2 / build 5. The owner has been asked to open TV and confirm guide cards/logos. Physical route switching and the UI/playback checklist remain pending. The USB video bridge is stopped; no fallback playback has been attempted. Keep the legacy relay compiled.

## Owner-reported home rendering

On installed 0.3.2 / build 5, the owner opened TV at home and confirmed game/channel cards and logos appear. No Mac video bridge was running. This accepts home guide/logo rendering; playback, route switching and the remaining physical checklist are pending.

## Physical playback report and investigation

Owner tested the live Panthers @ Packers game: long loading, backup attempt, black video and eventual unavailable-feed error. Troy @ James Madison fails similarly. Cleveland @ Atlanta and Sacramento @ New Orleans reportedly worked great. This is a pass for those two NBA playback attempts, not blanket league acceptance or measured startup/audio-sync/endurance evidence.

Retrieved existing iPad screenshots privately by USB file access (no automated capture or app interaction). Five recent TV screenshots show the NFL guide, loading, backup toast and unavailable-feed error. Originals remain on the iPad; copies are outside Git under the private acceptance directory. They contain private device metadata, so were not committed. Older unrelated copied PNGs were removed from the task's local copy directory.

Read-only production guide and Dispatcharr metadata identify two NFL event feeds and one NCAAF event feed. The first NFL source is labeled 4K; its regular backup is separate. The NCAAF source is named `NCAAF 02: ESPN2`. Source names/quality labels alone do not prove codec or availability. During the owner's failures, correlated Dispatcharr logs show each selected upstream delivering briefly, ending, retrying three times and entering ERROR with no untried source remaining. This reproduces upstream exhaustion in server evidence but does not yet establish its root cause or exclude an app issue. No server configuration was changed and no additional streams were opened by the agent.

Next: owner returns to the guide so playback is stopped, then inspect one failing feed at a time (playlist/segments, codec and whether it is a finite placeholder) and compare the working path. Do not guess a transcoding or source-mapping fix from labels alone. Keep the legacy relay.

## Bounded source probes after playback stopped

Owner confirmed returning to the guide. Sequential, bounded captures through Dispatcharr HLS found regular NFL and NCAAF sources currently delivering 720p59.94 H.264 Main/HE-AAC broadcast video, while the first NFL source delivers 2160p59.94 HEVC Main 10/AC-3, unsupported on this iPad. No transcoding or Dispatcharr changes were made. Earlier upstream-end/retry evidence remains valid; these later successful captures do not explain that transient condition or establish iPad playback acceptance. See [stream findings](STREAMS.md#032-physical-failure-follow-up).

Gateway exclusion support passes 9 tests, including primary/backup/tile exclusion and unrelated league preservation. An in-memory candidate against current M3U/EPG/scoreboards selects the regular NFL source without the incompatible primary. Deployment of this new gateway source and private exclusion setting awaits owner approval. There is no new app package/install in this investigation.

Final read-only Dispatcharr cleanup check: zero active proxy clients. No agent capture remains running.
