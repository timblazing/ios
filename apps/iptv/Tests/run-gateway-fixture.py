#!/usr/bin/env python3
"""Run the Foundation client against real loopback HTTP responses; no private data."""
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

fixture = json.loads((Path(__file__).parent / 'fixtures/guide.json').read_text())
state = {'home': 'up', 'requests': []}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/control?home='):
            state['home'] = self.path.split('=', 1)[1]
            return self.reply(200, b'ok')
        state['requests'].append((self.path, self.headers.get('If-None-Match')))
        if self.path == '/slow/guide.json':
            time.sleep(7)
        if self.path == '/unavailable/guide.json' or (self.path == '/home/guide.json' and state['home'] == 'down'):
            return self.reply(503, b'unavailable')
        if self.path == '/malformed/guide.json':
            return self.reply(200, b'{"leagues":"bad"}')
        if self.path == '/uncached304/guide.json' or self.headers.get('If-None-Match') == '"same-validator"':
            return self.reply(304, b'')
        doc = json.loads(json.dumps(fixture))
        # Deliberately share the validator across origins to catch cross-route reuse.
        stream = 'http://127.0.0.1:19494/dispatcharr/proxy/test' if self.path.startswith('/bridge/') else 'http://192.0.2.10/proxy/test'
        doc['leagues'][0]['channels'] = [{'id': 'test', 'name': 'Test', 'stream': stream, 'logo': '/logo?u=test', 'epg': []}]
        self.reply(200, json.dumps(doc).encode())

    def reply(self, status, body):
        self.send_response(status)
        self.send_header('ETag', '"same-validator"')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
server.daemon_threads = True
worker = threading.Thread(target=server.serve_forever, daemon=True)
worker.start()
try:
    subprocess.run([sys.argv[1], f'http://127.0.0.1:{server.server_port}'], check=True, timeout=30)
    requests = state['requests']
    assert requests[:2] == [('/home/guide.json', None), ('/home/guide.json', '"same-validator"')]
    assert ('/bridge/guide.json', None) in requests
    # The first recovery request must not carry the bridge validator.
    bridge_index = next(i for i, (p, _) in enumerate(requests) if p == '/bridge/guide.json')
    assert requests[bridge_index + 1] == ('/home/guide.json', None)
    print('HTTP fixture confirms validators remain scoped to the active route')
finally:
    server.shutdown()
    server.server_close()
    worker.join()
