#!/usr/bin/env python3
"""Loopback-only TV guide/HLS adapter for an SSH reverse forward over USB."""
import argparse
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Bridge:
    def __init__(self, gateway, dispatcharr, device_base, dispatcharr_upstream=None):
        self.gateway = gateway.rstrip('/')
        self.dispatcharr = dispatcharr.rstrip('/')
        self.dispatcharr_upstream = (dispatcharr_upstream or dispatcharr).rstrip('/')
        self.device_base = device_base.rstrip('/')
        self.opener = urllib.request.build_opener(NoRedirect)

    def media_url(self, value, base):
        url = urllib.parse.urlsplit(urllib.parse.urljoin(base, value))
        expected = urllib.parse.urlsplit(self.dispatcharr)
        if (url.scheme, url.netloc) != (expected.scheme, expected.netloc) or not url.path.startswith('/proxy/'):
            raise ValueError('Unexpected media origin or path')
        if url.username or url.password or url.fragment:
            raise ValueError('Unexpected media credentials or fragment')
        return self.device_base + '/dispatcharr' + urllib.parse.urlunsplit(('', '', url.path, url.query, ''))

    def guide(self, data):
        doc = json.loads(data)
        for league in doc.get('leagues', []):
            channels = list(league.get('channels', []))
            for game in league.get('games', []):
                channels.extend(game.get('channels', []))
            for channel in channels:
                channel['stream'] = self.media_url(channel['stream'], self.dispatcharr + '/')
        return json.dumps(doc, separators=(',', ':')).encode()

    def playlist(self, data, upstream):
        text = data.decode('utf-8')
        lines = []
        for line in text.splitlines():
            if line and not line.startswith('#'):
                line = self.media_url(line, upstream)
            elif line.startswith('#'):
                line = re.sub(r'URI="([^"]+)"', lambda m: 'URI="' + self.media_url(m[1], upstream) + '"', line)
            lines.append(line)
        return ('\n'.join(lines) + '\n').encode()

    def handler(self):
        bridge = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                path = urllib.parse.urlsplit(self.path)
                if path.scheme or path.netloc or path.fragment:
                    return self.reply(400, b'Invalid path')
                media = path.path.startswith('/dispatcharr/proxy/')
                if media:
                    logical_url = bridge.dispatcharr + self.path[len('/dispatcharr'):]
                    upstream = bridge.dispatcharr_upstream + self.path[len('/dispatcharr'):]
                elif path.path in ('/guide.json', '/logo', '/health'):
                    upstream = bridge.gateway + self.path
                else:
                    return self.reply(404, b'Not found')
                headers = {}
                for key in ('If-None-Match', 'Range'):
                    if self.headers.get(key):
                        headers[key] = self.headers[key]
                try:
                    request = urllib.request.Request(upstream, headers=headers)
                    try:
                        response = bridge.opener.open(request, timeout=35)
                    except urllib.error.HTTPError as error:
                        response = error
                    with response:
                        status = response.code
                        extra = {k: response.headers[k] for k in ('ETag', 'Cache-Control', 'Content-Range', 'Accept-Ranges')
                                 if response.headers.get(k)}
                        if status in (301, 302, 303, 307, 308):
                            if not media:
                                raise ValueError('Unexpected gateway redirect')
                            extra['Location'] = bridge.media_url(response.headers['Location'], logical_url)
                            return self.reply(status, b'', extra=extra)
                        data = response.read()
                        ctype = response.headers.get('Content-Type', 'application/octet-stream')
                        if status == 200 and path.path == '/guide.json':
                            data = bridge.guide(data)
                        elif status == 200 and media and (path.path.endswith('.m3u8') or data.startswith(b'#EXTM3U') or
                                                          'mpegurl' in ctype.lower()):
                            data = bridge.playlist(data, logical_url)
                        return self.reply(status, data, ctype, extra)
                except Exception:
                    # Upstream exceptions contain private addresses and tokens.
                    return self.reply(502, b'Bridge upstream unavailable')

            def reply(self, status, data, ctype='text/plain', extra=None):
                self.send_response(status)
                self.send_header('Content-Type', ctype)
                self.send_header('Content-Length', str(len(data)))
                for key, value in (extra or {}).items():
                    self.send_header(key, value)
                self.end_headers()
                try:
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    pass

            def log_message(self, *args):
                pass  # Request paths can contain HLS session tokens.

        return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, help='Private JSON file outside the repository')
    args = parser.parse_args()
    with open(args.config) as f:
        config = json.load(f)
    bridge = Bridge(config['gateway'], config['dispatcharr'], config['device_base'], config.get('dispatcharr_upstream'))
    port = config.get('listen_port', 19394)
    server = ThreadingHTTPServer(('127.0.0.1', port), bridge.handler())
    server.daemon_threads = True
    print('TV USB adapter listening on loopback port', port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
