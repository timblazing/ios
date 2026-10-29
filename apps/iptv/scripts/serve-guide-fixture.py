#!/usr/bin/env python3
"""Serve a local simulator guide; never copy an unsanitized fixture into the repo."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("fixture", type=Path)
parser.add_argument("--port", type=int, default=19493)
parser.add_argument("--fail-flag", type=Path, help="Return 503 while this file exists")
args = parser.parse_args()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/guide.json":
            self.send_error(404)
            return
        if args.fail_flag and args.fail_flag.exists():
            self.send_error(503)
            return
        data = args.fixture.read_bytes()
        etag = '"' + hashlib.sha256(data).hexdigest() + '"'
        status = 304 if self.headers.get("If-None-Match") == etag else 200
        self.send_response(status)
        self.send_header("ETag", etag)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        if status == 200:
            self.wfile.write(data)

HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
