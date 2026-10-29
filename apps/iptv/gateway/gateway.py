"""TV gateway: one small JSON guide for the iPad, built from Dispatcharr and ESPN.

The iPad makes one request (/guide.json) instead of parsing the M3U, the XMLTV and
three scoreboards itself, and fetches small cached logos from /logo. Streams are not
proxied: each channel carries Dispatcharr's own HLS URL.
"""
import gzip, hashlib, io, json, os, re, threading, time, urllib.parse, urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zoneinfo import ZoneInfo

DISPATCHARR = os.environ.get("DISPATCHARR_URL", "").rstrip("/")
PORT = int(os.environ.get("PORT", "9292"))
TZ = ZoneInfo(os.environ.get("TZ", "America/Chicago"))
CACHE_DIR = os.environ.get("CACHE_DIR", "/cache")
LEAGUES = [  # tab order in the app; NFL asks for the whole current week, the others for today and tomorrow
    ("nfl", "NFL", "football/nfl", None),
    ("nba", "NBA", "basketball/nba", ""),
    ("ncaaf", "NCAAF", "football/college-football", "&groups=80"),
]
ESPN = "https://site.api.espn.com/apis/site/v2/sports/{}/scoreboard"
LOGO_HOSTS = ("a.espncdn.com", "raw.githubusercontent.com")
TV_LOGOS = "https://raw.githubusercontent.com/tv-logo/tv-logos/main/countries/united-states/{}.png"
# Normalized network name -> tv-logos file. ESPN broadcast names and channel names both normalize here.
NETWORKS = {
    "espn": "espn-us", "espn2": "espn-2-us", "espnu": "espn-u-us", "abc": "abc-us",
    "cbs": "cbs-logo-white-us", "fox": "fox-us", "nbc": "nbc-us", "accnetwork": "acc-network-us",
    "bigtennetwork": "big-ten-network-us", "secnetwork": "sec-network-us",
    "cbssportsnetwork": "cbs-sports-network-us", "fs1": "fox-sports-1-us", "cw": "cw-us",
    "tnt": "tnt-us", "usanetwork": "usa-us", "nflnetwork": "nfl-network-us",
    "nflredzone": "nfl-red-zone-us", "nbatv": "nba-tv-us",
}
ALIASES = {"accn": "accnetwork", "btn": "bigtennetwork", "secn": "secnetwork", "cbssn": "cbssportsnetwork",
           "foxsports1": "fs1", "usanet": "usanetwork", "usa": "usanetwork", "thecw": "cw", "redzone": "nflredzone", "nflnet": "nflnetwork"}


def fetch(url, timeout=15):
    req = urllib.request.Request(url, headers={"User-Agent": "tv-gateway/1"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def net_key(name):
    k = re.sub(r"[^a-z0-9]", "", name.lower().replace("&", "and"))
    return ALIASES.get(k, k)


# ---- sources -----------------------------------------------------------------

def parse_m3u(text):
    chans, info = [], None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#EXTINF"):
            attrs = dict(re.findall(r'([\w-]+)="([^"]*)"', line))
            info = {"id": attrs.get("tvg-id", ""), "number": attrs.get("tvg-chno", ""),
                    "group": attrs.get("group-title", ""), "logo": attrs.get("tvg-logo", ""),
                    "name": line.rsplit(",", 1)[-1].strip()}
        elif line and not line.startswith("#") and info:
            info["stream"] = line + ("&" if "?" in line else "?") + "output_format=hls"
            chans.append(info)
            info = None
    return chans


def parse_xmltv(data, now, ids):
    """Now and next programme per channel id, only for channels we keep."""
    progs = {}
    for _, el in ET.iterparse(io.BytesIO(data)):
        if el.tag != "programme":
            continue
        cid = el.get("channel")
        if cid in ids:
            start, stop = xmltv_time(el.get("start")), xmltv_time(el.get("stop"))
            if start and stop and stop > now:
                progs.setdefault(cid, []).append({"title": el.findtext("title") or "",
                                                  "start": iso(start), "end": iso(stop), "_s": start})
        el.clear()
    return {cid: [{k: v for k, v in p.items() if k != "_s"} for p in sorted(ps, key=lambda p: p["_s"])[:2]]
            for cid, ps in progs.items()}


def xmltv_time(s):
    try:
        return datetime.strptime(s, "%Y%m%d%H%M%S %z")
    except (TypeError, ValueError):
        return None


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_scoreboard(doc):
    games = []
    for ev in doc.get("events", []):
        comp = ev["competitions"][0]
        st = comp["status"]["type"]
        teams = {}
        for c in comp["competitors"]:
            t = c["team"]
            teams[c["homeAway"]] = {
                "abbr": t.get("abbreviation", ""), "name": t.get("displayName", ""),
                "location": t.get("location", ""), "nick": t.get("name") or t.get("shortDisplayName", ""),
                "short": t.get("shortDisplayName", ""),
                "color": t.get("color", ""), "alt": t.get("alternateColor", ""),
                "logo": t.get("logo", ""),
                "record": next((r["summary"] for r in c.get("records", []) if r.get("type") == "total"), ""),
                "score": c.get("score", "") if st["state"] != "pre" else "",
                "rank": (c.get("curatedRank") or {}).get("current", 99),
            }
        tv = [n for b in comp.get("broadcasts", []) for n in b.get("names", [])]
        games.append({"id": ev["id"], "start": ev["date"], "state": st["state"],
                      "detail": comp["status"]["type"].get("shortDetail", ""),
                      "away": teams.get("away"), "home": teams.get("home"), "tv": tv})
    return games


# ---- matching ----------------------------------------------------------------

def words(s):
    return " " + re.sub(r"[^a-z0-9]+", " ", s.lower()) + " "


def team_in(team, text):
    for key in ("nick", "location", "short"):
        v = team.get(key, "")
        if len(v) > 2 and words(v) in text:
            return True
    return False


def match_game(name, games):
    text = words(name)
    for g in games:
        if g["away"] and g["home"] and team_in(g["away"], text) and team_in(g["home"], text):
            return g
    return None


def build_league(lid, title, chans, games, epg):
    by_net, cards, tiles = {}, {}, []
    for c in chans:
        k = net_key(c["name"])
        if k in NETWORKS:
            by_net[k] = c
            tiles.append(c)
            continue
        g = match_game(c["name"], games)
        if g:
            cards.setdefault(g["id"], []).append(c)
        else:
            tiles.append(c)
    out_games = []
    for g in games:
        feeds = cards.get(g["id"], [])
        feeds += [by_net[net_key(n)] for n in g["tv"] if net_key(n) in by_net and by_net[net_key(n)] not in feeds]
        if not feeds:
            continue
        gg = dict(g, tv=g["tv"][0] if g["tv"] else "", channels=[channel_out(c, epg) for c in feeds])
        for side in ("away", "home"):
            gg[side] = {k: v for k, v in g[side].items() if k not in ("location", "short", "rank")}
            gg[side]["logo"] = logo_url(g[side]["logo"].replace("/500/", "/500-dark/"))
        out_games.append(gg)
    order = {"in": 0, "pre": 1, "post": 2}
    out_games.sort(key=lambda g: (order.get(g["state"], 3), g["start"]))
    return {"id": lid, "title": title, "games": out_games, "channels": [channel_out(c, epg) for c in tiles]}


def channel_out(c, epg):
    k = net_key(c["name"])
    logo = TV_LOGOS.format(NETWORKS[k]) if k in NETWORKS else c.get("logo", "")
    return {"id": c["id"], "number": c["number"], "name": c["name"], "stream": c["stream"],
            "logo": logo_url(logo), "epg": epg.get(c["id"], [])}


def logo_url(src):
    return "/logo?" + urllib.parse.urlencode({"u": src}) if src else ""


# ---- state -------------------------------------------------------------------

class Guide:
    def __init__(self):
        self.lock = threading.Lock()
        self.chans, self.epg, self.scores = [], {}, {}
        self.body, self.gz, self.etag, self.updated = b"{}", gzip.compress(b"{}"), '"0"', 0
        self.errors = {}

    def refresh_channels(self):
        self.chans = parse_m3u(fetch(DISPATCHARR + "/output/m3u").decode("utf-8", "replace"))
        ids = {c["id"] for c in self.chans}
        self.epg = parse_xmltv(fetch(DISPATCHARR + "/output/epg", 60), datetime.now(timezone.utc), ids)

    def refresh_scores(self):
        today = datetime.now(TZ)
        days = [(today + timedelta(days=d)).strftime("%Y%m%d") for d in (0, 1)]
        for lid, _, path, extra in LEAGUES:
            games, seen = [], set()
            urls = [ESPN.format(path)] if extra is None else [ESPN.format(path) + "?dates=" + d + extra for d in days]
            for u in urls:
                for g in parse_scoreboard(json.loads(fetch(u))):
                    if g["id"] not in seen:
                        seen.add(g["id"])
                        games.append(g)
            self.scores[lid] = games

    def rebuild(self):
        leagues = []
        for lid, title, _, _ in LEAGUES:
            chans = [c for c in self.chans if words(title) in words(c["group"])]
            leagues.append(build_league(lid, title, chans, self.scores.get(lid, []), self.epg))
        doc = {"updated": iso(datetime.now(timezone.utc)), "leagues": leagues}
        body = json.dumps(doc, separators=(",", ":")).encode()
        with self.lock:
            self.body, self.gz = body, gzip.compress(body)
            self.etag = '"%s"' % hashlib.sha1(body).hexdigest()[:16]
            self.updated = time.time()

    def live(self):
        return any(g["state"] == "in" for gs in self.scores.values() for g in gs)


GUIDE = Guide()


def loop(name, fn, interval):
    while True:
        try:
            fn()
            GUIDE.errors.pop(name, None)
            GUIDE.rebuild()
        except Exception as e:  # keep serving the last good guide
            GUIDE.errors[name] = "%s: %s" % (type(e).__name__, e)
        time.sleep(interval() if callable(interval) else interval)


# ---- logos -------------------------------------------------------------------

def logo_png(src, size):
    host = urllib.parse.urlparse(src).hostname or ""
    if host not in LOGO_HOSTS and not (DISPATCHARR and src.startswith(DISPATCHARR + "/")):
        raise PermissionError(host)
    path = os.path.join(CACHE_DIR, hashlib.sha1(("%s@%d" % (src, size)).encode()).hexdigest() + ".png")
    if os.path.exists(path):
        with open(path, "rb") as f:
            return f.read()
    from PIL import Image
    img = Image.open(io.BytesIO(fetch(src))).convert("RGBA")
    img.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - img.width) // 2, (size - img.height) // 2))
    out = io.BytesIO()
    canvas.save(out, "PNG", optimize=True)
    data = out.getvalue()
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(path + ".tmp", "wb") as f:
        f.write(data)
    os.replace(path + ".tmp", path)
    return data


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(url.query)
        if url.path == "/guide.json":
            with GUIDE.lock:
                body, gz, etag = GUIDE.body, GUIDE.gz, GUIDE.etag
            if self.headers.get("If-None-Match") == etag:
                return self.reply(304, b"", extra={"ETag": etag})
            use_gz = "gzip" in (self.headers.get("Accept-Encoding") or "")
            extra = {"ETag": etag, "Cache-Control": "no-cache"}
            if use_gz:
                extra["Content-Encoding"] = "gzip"
            return self.reply(200, gz if use_gz else body, "application/json", extra)
        if url.path == "/logo":
            size = max(16, min(256, int((q.get("s") or ["96"])[0])))
            try:
                data = logo_png((q.get("u") or [""])[0], size)
            except PermissionError:
                return self.reply(403, b"host not allowed")
            except Exception:
                return self.reply(404, b"no logo")
            return self.reply(200, data, "image/png", {"Cache-Control": "public, max-age=604800"})
        if url.path == "/health":
            doc = {"age": round(time.time() - GUIDE.updated), "channels": len(GUIDE.chans), "errors": GUIDE.errors}
            return self.reply(200, json.dumps(doc).encode(), "application/json")
        self.reply(404, b"not found")

    def reply(self, code, body, ctype="text/plain", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        pass  # clients (AVPlayer, the app) drop keep-alive connections all the time


def main():
    if not DISPATCHARR:
        raise SystemExit("set DISPATCHARR_URL")
    threading.Thread(target=loop, args=("channels", GUIDE.refresh_channels, 300), daemon=True).start()
    threading.Thread(target=loop, args=("scores", GUIDE.refresh_scores, lambda: 30 if GUIDE.live() else 120),
                     daemon=True).start()
    Server(("", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
