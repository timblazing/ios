import importlib.util
import json
from pathlib import Path
import unittest
import threading
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

spec = importlib.util.spec_from_file_location('bridge', Path(__file__).parents[1] / 'bridge.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge = module.Bridge('http://127.0.0.1:19292', 'http://192.0.2.10:9191', 'http://127.0.0.1:19494')
        self.original = 'http://192.0.2.10:9191/proxy/hls/test/index.m3u8'

    def test_guide_rewrites_tiles_and_backup_feeds(self):
        channel = {'stream': self.original, 'logo': '/logo?u=test'}
        doc = {'leagues': [{'channels': [channel], 'games': [{'channels': [channel, channel]}]}]}
        result = json.loads(self.bridge.guide(json.dumps(doc).encode()))['leagues'][0]
        for c in result['channels'] + result['games'][0]['channels']:
            self.assertEqual(c['stream'], 'http://127.0.0.1:19494/dispatcharr/proxy/hls/test/index.m3u8')
            self.assertEqual(c['logo'], '/logo?u=test')

    def test_playlist_rewrites_relative_root_absolute_and_attribute_uris(self):
        source = ('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
                  '#EXT-X-MAP:URI="/proxy/hls/test/init.mp4"\nsegment.ts\n'
                  'http://192.0.2.10:9191/proxy/hls/test/next.ts\n')
        result = self.bridge.playlist(source.encode(), self.original).decode()
        for suffix in ('key.bin', 'init.mp4', 'segment.ts', 'next.ts'):
            self.assertIn('http://127.0.0.1:19494/dispatcharr/proxy/hls/test/' + suffix, result)
        self.assertNotIn('192.0.2.10', result)

    def test_unexpected_media_origin_or_path_is_rejected(self):
        for value in ('https://example.com/video.ts', '//example.com/video.ts', '/admin/',
                      'http://user:pass@192.0.2.10:9191/proxy/test', '/proxy/x#fragment'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.bridge.media_url(value, self.original)

    def test_redirect_preserves_query_and_routes_through_usb(self):
        self.assertEqual(self.bridge.media_url('/proxy/hls/test/index.m3u8?example=1', self.original),
                         'http://127.0.0.1:19494/dispatcharr/proxy/hls/test/index.m3u8?example=1')


class BridgeHTTPTests(unittest.TestCase):
    def test_guide_conditional_redirect_playlist_and_segment_round_trip(self):
        class Upstream(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/guide.json':
                    if self.headers.get('If-None-Match') == '"test"':
                        self.send_response(304); self.end_headers(); return
                    body = json.dumps({'leagues': [{'channels': [{'stream':
                        'http://192.0.2.10:9191/proxy/ts/example?output_format=hls'}], 'games': []}]}).encode()
                    ctype = 'application/json'
                elif self.path == '/proxy/ts/example?output_format=hls':
                    self.send_response(302)
                    self.send_header('Location', '/proxy/hls/example/index.m3u8')
                    self.end_headers(); return
                elif self.path == '/proxy/hls/example/index.m3u8':
                    body = b'#EXTM3U\n#EXTINF:4,\nsegment.ts?example=1\n'
                    ctype = 'application/vnd.apple.mpegurl'
                elif self.path == '/proxy/hls/example/segment.ts?example=1':
                    body = b'test-segment'
                    ctype = 'video/mp2t'
                else:
                    self.send_response(404); self.end_headers(); return
                self.send_response(200)
                self.send_header('Content-Type', ctype)
                self.send_header('ETag', '"test"')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers(); self.wfile.write(body)

            def log_message(self, *args):
                pass

        upstream = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
        endpoint = 'http://127.0.0.1:' + str(upstream.server_port)
        bridge = module.Bridge(endpoint, 'http://192.0.2.10:9191', '', endpoint)
        adapter = ThreadingHTTPServer(('127.0.0.1', 0), bridge.handler())
        bridge.device_base = 'http://127.0.0.1:' + str(adapter.server_port)
        workers = [threading.Thread(target=s.serve_forever, daemon=True) for s in (upstream, adapter)]
        for worker in workers: worker.start()
        try:
            with urllib.request.urlopen(bridge.device_base + '/guide.json') as response:
                stream = json.load(response)['leagues'][0]['channels'][0]['stream']
            with urllib.request.urlopen(stream) as response:
                playlist = response.read().decode()
                self.assertEqual(response.url, bridge.device_base + '/dispatcharr/proxy/hls/example/index.m3u8')
            segment_url = playlist.splitlines()[-1]
            with urllib.request.urlopen(segment_url) as response:
                self.assertEqual(response.read(), b'test-segment')
            req = urllib.request.Request(bridge.device_base + '/guide.json', headers={'If-None-Match': '"test"'})
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(req)
            self.assertEqual(error.exception.code, 304)
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(bridge.device_base + '/admin/')
            self.assertEqual(error.exception.code, 404)
        finally:
            for server in (adapter, upstream): server.shutdown(); server.server_close()
            for worker in workers: worker.join()


if __name__ == '__main__':
    unittest.main()
