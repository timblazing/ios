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
