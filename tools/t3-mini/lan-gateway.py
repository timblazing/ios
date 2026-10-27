#!/usr/bin/env python3
"""Temporary trusted-LAN read-only adapter for a loopback T3 Code desktop host."""
import argparse
import http.client
import ipaddress
import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

MAX_RESPONSE = 8 * 1024 * 1024


def allowed(method, path, body=b''):
    if method == 'GET':
        return path in ('/.well-known/t3/environment', '/api/orchestration/shell') or bool(
            re.fullmatch(r'/api/orchestration/threads/[A-Za-z0-9_-]+/bounded', path))
    if method != 'POST' or path != '/oauth/token':
        return False
    try:
        form = parse_qs(body.decode('utf-8'), strict_parsing=True)
    except (ValueError, UnicodeDecodeError):
        return False
    expected = {
        'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
        'subject_token_type': 'urn:t3:params:oauth:token-type:environment-bootstrap',
        'requested_token_type': 'urn:ietf:params:oauth:token-type:access_token',
        'scope': 'orchestration:read',
    }
    keys = set(expected) | {'subject_token', 'client_label', 'client_device_type', 'client_os'}
    return (set(form) <= keys and all(len(v) == 1 for v in form.values())
            and all(form.get(k) == [v] for k, v in expected.items())
            and bool(form.get('subject_token', [''])[0]))


class Gateway(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_args):
        pass  # Pairing credentials and conversation URLs must not enter access logs.

    def do_GET(self):
        self.forward()

    def do_POST(self):
        self.forward()

    def reply(self, code, payload):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(payload)

    def forward(self):
        self.connection.settimeout(20)
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            return self.reply(400, b'{"error":"invalid request"}')
        if length < 0 or length > 8192 or self.headers.get('Transfer-Encoding'):
            return self.reply(413, b'{"error":"unsupported request body"}')
        if self.command == 'GET' and length:
            return self.reply(400, b'{"error":"unexpected request body"}')
        body = self.rfile.read(length)
        if not allowed(self.command, self.path, body):
            return self.reply(403, b'{"error":"read-only prototype endpoint"}')
        headers = {key: self.headers[key] for key in
                   ('Authorization', 'Content-Type', 'x-t3-orchestration-protocol') if key in self.headers}
        upstream = http.client.HTTPConnection(self.server.upstream.hostname,
                                              self.server.upstream.port or 80, timeout=20)
        try:
            upstream.request(self.command, self.path, body=body or None, headers=headers)
            response = upstream.getresponse()
            payload = response.read(MAX_RESPONSE + 1)
            if len(payload) > MAX_RESPONSE:
                return self.reply(502, b'{"error":"host response too large"}')
            self.reply(response.status, payload)
        except (OSError, http.client.HTTPException):
            self.reply(502, b'{"error":"T3 host unavailable"}')
        finally:
            upstream.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--listen', required=True, help='This Mac\'s private LAN IPv4 address')
    parser.add_argument('--port', type=int, default=3774)
    parser.add_argument('--upstream', default='http://127.0.0.1:3773')
    args = parser.parse_args()
    listen = ipaddress.ip_address(args.listen)
    upstream = urlsplit(args.upstream)
    if listen.version != 4 or not listen.is_private or listen.is_unspecified:
        parser.error('--listen must be an explicit private IPv4 address')
    if (upstream.scheme != 'http' or upstream.hostname not in ('127.0.0.1', 'localhost', '::1')
            or upstream.path not in ('', '/') or upstream.username or upstream.password
            or upstream.query or upstream.fragment):
        parser.error('--upstream must be a loopback HTTP origin')
    server = ThreadingHTTPServer((args.listen, args.port), Gateway)
    server.daemon_threads = True
    server.upstream = upstream
    print('T3 Mini read-only LAN adapter listening on http://%s:%s' % (args.listen, args.port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
