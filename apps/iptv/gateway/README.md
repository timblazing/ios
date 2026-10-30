# TV gateway

A small Python service on the home server that gives the iPad one ready-made guide. It merges Dispatcharr's M3U and XMLTV with ESPN's public scoreboards, matches channels to games, and serves small cached logos. It doesn't touch video: each channel carries Dispatcharr's own HLS URL, which AVPlayer plays directly.

Running on `raygun` at `~/docker/tv-gateway/`, port **9292**.

## API

Logo paths in the guide are relative to the gateway's base URL.

### `GET /guide.json`

About 25 KB, or about 4 KB gzipped. Supports `ETag`/`If-None-Match` (returns 304 when unchanged). Rebuilt every 30 s while any game is live, 2 min otherwise. Channels and the EPG are refreshed every 5 min.

```jsonc
{
  "updated": "2026-10-29T16:05:00Z",
  "leagues": [                       // tab order: NFL, NBA, NCAAF
    {
      "id": "nfl", "title": "NFL",
      "games": [                     // live first, then upcoming, then final; by start time
        {
          "id": "401...", "start": "2026-10-30T00:15Z",
          "state": "pre",            // pre | in | post (ESPN status)
          "detail": "10/29 - 8:15 PM EDT",   // ESPN shortDetail: "Q2 3:21", "Half", "Final"
          "tv": "Prime Video",       // first broadcast name, for the card subtitle
          "away": { "abbr": "CAR", "name": "Carolina Panthers", "nick": "Panthers",
                    "color": "0085ca", "alt": "000000", "logo": "/logo?u=...",
                    "record": "5-3", "score": "" },     // score is "" before the game
          "home": { ... },
          "channels": [ Channel, ... ]   // first is the primary feed; the rest are backups
        }
      ],
      "channels": [ Channel, ... ]   // network/24-7 channels and anything that didn't match a game
    }
  ]
}
```

`Channel`:

```jsonc
{ "id": "1402", "number": "1402", "name": "Panthers at Packers",
  "stream": "http://<dispatcharr>/proxy/ts/stream/<uuid>?output_format=hls",
  "logo": "/logo?u=...",
  "epg": [ { "title": "...", "start": "...Z", "end": "...Z" } ] }   // now and next, may be empty
```

Games with no channel are dropped. A game is matched to a channel when both teams' nickname, location or short name appear as whole words in the channel name (`PELICANS vs KINGS`, `Panthers at Packers`, `NFL | 02 - 1pm Ravens at Bills`, `NC State at Wake Forest`). Network channels (ESPN, CBSSN, NFL NETWORK…) are added as feeds for the games ESPN says they carry. League group names are matched as whole tokens, so both `NFL` and provider labels such as `US| NFL PPV` are accepted without matching WNBA as NBA. Name aliases live in `NETWORKS`/`ALIASES` in `gateway.py`.

### `GET /logo?u=<url>&s=<px>`

Fetches, fits into an `s`×`s` transparent PNG (default 96, 16–256), and caches it on disk for good. Only ESPN's CDN, `raw.githubusercontent.com` ([tv-logo/tv-logos](https://github.com/tv-logo/tv-logos)) and the Dispatcharr host are allowed. Use `s=96` for 48 pt marks on Retina. The response has `Cache-Control: max-age=604800`.

### `GET /health`

`{"age": seconds since last rebuild, "channels": n, "errors": {...}}`. On a source error the last good guide stays up.

## Config

`.env` on the server (never committed; see `.env.example`):

| Var | Example |
|---|---|
| `DISPATCHARR_URL` | `http://192.0.2.10:9191` |
| `TZ` | `America/Chicago` (decides "today" for NBA and NCAAF scoreboards) |
| `PORT` | `9292` |

## Run, test, deploy

```sh
python3 -m unittest discover -s tests          # no network needed
DISPATCHARR_URL=http://... CACHE_DIR=/tmp/gw PORT=9393 python3 gateway.py   # local run; logos need Pillow

# deploy (raygun has Docker; never run Docker on the Mac)
scp Dockerfile compose.yaml gateway.py raygun:docker/tv-gateway/
ssh raygun 'cd ~/docker/tv-gateway && docker compose up -d --build'
ssh raygun 'curl -s localhost:9292/health'
```

Standard library only, plus Pillow for logos.

## Network-logo source repair — 2026-10-29

The original source used the nonexistent `tv-logos/tv-logos` repository, causing upstream and gateway 404s. The source is now `tv-logo/tv-logos`; all 18 configured filenames exist there. Through the running gateway on raygun, each corrected source URL returned HTTP 200, `image/png`, and a 96×96 PNG. This exercised the existing allowlist, fetch, resize and cache path without opening video streams.

The owner-approved fixes were deployed to the live gateway in the 2026-10-29 evening continuation. Running source matches this checkout, all three generated leagues are populated, generated network-logo URLs use the corrected repository, and all 18 network-logo endpoints pass again. See [deployment evidence](../docs/VALIDATION-0.3.1.md#gateway-deployment--2026-10-29-continuation) and [rollback details](../docs/HANDOFF.md#continuation--2026-10-29-evening). Check the app after a guide refresh/relaunch. Physical iPad logo rendering remains unverified. The app's abbreviation fallback stays available.
