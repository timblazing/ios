import os, sys, unittest
from unittest.mock import patch
from datetime import datetime, timezone
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import gateway as gw

ZERO = "00000000-0000-0000-0000-00000000000"
M3U = "\n".join([
    "#EXTM3U",
    '#EXTINF:-1 tvg-id="1200" tvg-chno="1200" tvg-logo="" group-title="NBA",PELICANS vs KINGS',
    "http://192.0.2.1:9191/proxy/ts/stream/%s1" % ZERO,
    '#EXTINF:-1 tvg-id="1402" tvg-chno="1402" group-title="NFL",Panthers at Packers',
    "http://192.0.2.1:9191/proxy/ts/stream/%s2" % ZERO,
    '#EXTINF:-1 tvg-id="1403" tvg-chno="1403" group-title="NFL",Panthers at Packers',
    "http://192.0.2.1:9191/proxy/ts/stream/%s3" % ZERO,
    '#EXTINF:-1 tvg-id="1404" tvg-chno="1404" group-title="NFL",NFL  | 02 - 1pm Ravens at Bills',
    "http://192.0.2.1:9191/proxy/ts/stream/%s4" % ZERO,
    '#EXTINF:-1 tvg-id="1400" tvg-chno="1400" group-title="NFL",NFL NETWORK',
    "http://192.0.2.1:9191/proxy/ts/stream/%s5" % ZERO,
    '#EXTINF:-1 tvg-id="1500" tvg-chno="1500" group-title="NCAAF",ESPN',
    "http://192.0.2.1:9191/proxy/ts/stream/%s6" % ZERO,
    '#EXTINF:-1 tvg-id="1511" tvg-chno="1511" group-title="NCAAF",CBSSN',
    "http://192.0.2.1:9191/proxy/ts/stream/%s7" % ZERO,
])


def team(abbr, location, nick):
    return {"team": {"abbreviation": abbr, "displayName": location + " " + nick, "location": location,
                     "name": nick, "shortDisplayName": nick, "color": "000000", "logo": "https://a.espncdn.com/i/teamlogos/x/500/%s.png" % abbr}}


def event(eid, away, home, tv, state="pre"):
    a, h = team(*away), team(*home)
    a.update(homeAway="away", score="7"); h.update(homeAway="home", score="10")
    return {"id": eid, "date": "2026-10-30T00:15Z", "competitions": [{
        "competitors": [h, a], "broadcasts": [{"names": tv}],
        "status": {"type": {"state": state, "shortDetail": "Q2 3:21"}}}]}


class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.chans = gw.parse_m3u(M3U)

    def test_m3u_adds_hls_output(self):
        self.assertEqual(len(self.chans), 7)
        self.assertTrue(self.chans[0]["stream"].endswith("/%s1?output_format=hls" % ZERO))
        self.assertEqual(self.chans[3]["name"], "NFL  | 02 - 1pm Ravens at Bills")

    def test_nfl_dedupes_feeds_and_matches_both_orders(self):
        games = gw.parse_scoreboard({"events": [
            event("1", ("CAR", "Carolina", "Panthers"), ("GB", "Green Bay", "Packers"), ["NFL Net"], "in"),
            event("2", ("BAL", "Baltimore", "Ravens"), ("BUF", "Buffalo", "Bills"), ["CBS"]),
            event("3", ("NYJ", "New York", "Jets"), ("MIA", "Miami", "Dolphins"), ["FOX"]),
        ]})
        nfl = [c for c in self.chans if c["group"] == "NFL"]
        lg = gw.build_league("nfl", "NFL", nfl, games, {})
        self.assertEqual([g["id"] for g in lg["games"]], ["1", "2"])  # live first, no-feed game dropped
        self.assertEqual([c["number"] for c in lg["games"][0]["channels"]], ["1402", "1403", "1400"])  # event feeds, then the network
        self.assertEqual(lg["games"][0]["away"]["score"], "7")
        self.assertEqual([c["name"] for c in lg["channels"]], ["NFL NETWORK"])
        self.assertEqual(parse_qs(urlparse(lg["channels"][0]["logo"]).query)["u"],
                         ["https://raw.githubusercontent.com/tv-logo/tv-logos/main/countries/united-states/nfl-network-us.png"])

    def test_nba_uppercase_home_vs_away(self):
        games = gw.parse_scoreboard({"events": [
            event("9", ("SAC", "Sacramento", "Kings"), ("NO", "New Orleans", "Pelicans"), ["NBA TV"])]})
        lg = gw.build_league("nba", "NBA", [self.chans[0]], games, {})
        self.assertEqual(lg["games"][0]["channels"][0]["number"], "1200")
        self.assertIn("500-dark", lg["games"][0]["home"]["logo"])

    def test_college_game_on_network_channel(self):
        games = gw.parse_scoreboard({"events": [
            event("5", ("FAU", "Florida Atlantic", "Owls"), ("UNT", "North Texas", "Mean Green"), ["ESPN"]),
            event("6", ("TROY", "Troy", "Trojans"), ("JMU", "James Madison", "Dukes"), ["CBS Sports Network"]),
        ]})
        cf = [c for c in self.chans if c["group"] == "NCAAF"]
        lg = gw.build_league("ncaaf", "NCAAF", cf, games, {})
        self.assertEqual([[c["name"] for c in g["channels"]] for g in lg["games"]], [["ESPN"], ["CBSSN"]])
        self.assertEqual(len(lg["channels"]), 2)

    def test_team_words_do_not_match_inside_other_words(self):
        g = gw.parse_scoreboard({"events": [event("7", ("NE", "New England", "Patriots"), ("LAR", "Los Angeles", "Rams"), [])]})
        self.assertIsNone(gw.match_game("Rampage at Patriotsville", g))

    def test_xmltv_now_and_next(self):
        xml = b"""<tv>
<programme channel="1500" start="20261029180000 +0000" stop="20261029190000 +0000"><title>Old</title></programme>
<programme channel="1500" start="20261029200000 +0000" stop="20261029210000 +0000"><title>Next</title></programme>
<programme channel="1500" start="20261029190000 +0000" stop="20261029200000 +0000"><title>Now</title></programme>
<programme channel="9999" start="20261029190000 +0000" stop="20261029200000 +0000"><title>Skip</title></programme>
</tv>"""
        now = datetime(2026, 10, 29, 19, 30, tzinfo=timezone.utc)
        epg = gw.parse_xmltv(xml, now, {"1500"})
        self.assertEqual([p["title"] for p in epg["1500"]], ["Now", "Next"])
        self.assertNotIn("9999", epg)

    def test_guide_accepts_provider_prefixed_league_groups(self):
        guide = gw.Guide()
        guide.chans = [dict(c, group={"NFL": "US| NFL PPV", "NBA": "US| NBA PASS PPV ⁸ᴷ",
                                     "NCAAF": "US| NCAAF PPV"}[c["group"]]) for c in self.chans]
        guide.chans.append(dict(self.chans[0], group="US| WNBA PPV"))
        guide.rebuild()
        import json
        leagues = json.loads(guide.body)["leagues"]
        self.assertEqual([(l["id"], len(l["channels"])) for l in leagues],
                         [("nfl", 4), ("nba", 1), ("ncaaf", 2)])

    def test_logo_host_allowlist(self):
        with self.assertRaises(PermissionError):
            gw.logo_png("http://203.0.113.9/x.png", 64)

    def test_excluded_feed_never_reaches_game_or_network_tiles(self):
        guide = gw.Guide()
        guide.chans = self.chans
        guide.scores = {"nfl": gw.parse_scoreboard({"events": [
            event("1", ("CAR", "Carolina", "Panthers"), ("GB", "Green Bay", "Packers"), ["NFL Net"], "in")
        ]})}
        with patch.object(gw, "EXCLUDED_CHANNEL_NUMBERS", frozenset(["1402", "1400"])):
            guide.rebuild()
        import json
        leagues = json.loads(guide.body)["leagues"]
        nfl = next(l for l in leagues if l["id"] == "nfl")
        self.assertEqual([c["number"] for c in nfl["games"][0]["channels"]], ["1403"])
        self.assertNotIn("1400", [c["number"] for c in nfl["channels"]])
        self.assertEqual(next(l for l in leagues if l["id"] == "nba")["channels"][0]["number"], "1200")


if __name__ == "__main__":
    unittest.main()
