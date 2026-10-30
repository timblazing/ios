# TV over a private USB bridge

For physical iOS 10 acceptance away from home, the jailbroken iPad can reach the TV guide and Dispatcharr through a Mac on the tailnet. No Tailscale client is needed on the iPad and no endpoint is published on workplace Wi-Fi or the public internet.

The route is iPad loopback → SSH reverse forward over USB → Mac loopback adapter → SSH over Tailscale → home services. The adapter rewrites guide stream addresses, HLS redirects, playlist entries and URI attributes. Video segments pass through unchanged: no transcoding and no on-device TS segmenter. This tests AVPlayer's HLS handling through a bridge; latency/throughput findings also include the USB/Mac/tailnet path.

## Prerequisites and setup

The owner must approve device installation and remote-access setup. Confirm the USB target is iPad4,5 / iOS 10.3.3 and use existing SSH key authentication (request credentials privately if needed). Never guess passwords. Keep TV closed while updating preferences and save the original preferences privately for restoration.

1. Use `iproxy -l -u <verified-device-id> -s 127.0.0.1 22922:22` to expose the iPad SSH port on Mac loopback. Keep SSH host keys in the task's private state directory.
2. Forward the guide and Dispatcharr through `ssh -NT` to the home host. Bind both local forwards to `127.0.0.1`. In this acceptance session, the guide candidate runs only on raygun loopback port 19293; Mac ports 19292 and 19291 reach the candidate and Dispatcharr respectively. Run Docker only on raygun.
3. Store the adapter config in a mode-600 JSON file inside a mode-700 directory **outside the repo**. Required keys: `gateway` (Mac guide forward), `dispatcharr` (original guide's Dispatcharr origin), `dispatcharr_upstream` (Mac Dispatcharr forward), `device_base` (`http://127.0.0.1:19494`), and `listen_port` (`19394`). Do not commit actual origins, stream data, preferences or config. The adapter intentionally rejects media from other origins or paths outside `/proxy/`.
4. Run `python3 tools/tv-usb/bridge.py --config <private-config.json>`. It listens only on Mac loopback.
5. Over the iPad SSH connection, request `-R 127.0.0.1:19494:127.0.0.1:19394`, with `ExitOnForwardFailure=yes` and keepalives. This creates the iPad loopback entry point.
6. Verify `/guide.json` from the iPad using its `curl`, without printing private responses. With TV closed, use the device's preferences tool as mobile to set only `com.local.iptv` / `gateway.baseURL` to `http://127.0.0.1:19494`. Preserve `server.baseURL`. This preconfigures the installed app without putting private configuration in an IPA/DEB.
7. Let the owner open TV and verify guide rendering, then test one stream at a time. Do not automate app launch or touch via SSH; T3 device interaction uses the Device panel when supported, otherwise the owner drives the legacy physical iPad.

## Validation and cleanup

```sh
python3 -m unittest discover -s tools/tv-usb/Tests
python3 -m unittest discover -s apps/iptv/gateway/tests
```

Tests cover tile/backup-feed rewriting, rejection of unexpected media origins, HLS relative/root/absolute and key/map URIs, query strings, redirects, HTTP round trips to a synthetic upstream, 304 handling and unrecognized paths. Do not log live request paths: they may contain session tokens.

Keep USB connected and the Mac awake during acceptance. Once the owner is done, stop only task-owned adapter, SSH forwards, iproxy and gateway candidate; remove temporary remote source files. The current candidate container is `tv-gateway-usb-acceptance`; production `tv-gateway` is unchanged. Use the private backup to restore the previous gateway preference when leaving bridge mode. Preserve unrelated preferences. Do not leave a dead loopback URL configured without telling the owner. Remove private backup/state files once no longer needed.
