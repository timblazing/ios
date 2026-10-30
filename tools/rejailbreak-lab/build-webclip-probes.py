#!/usr/bin/env python3
"""Generate harmless self-contained WebClips, with no exploit or network resources."""
import argparse
import base64
import hashlib
import html
import json
from pathlib import Path
import plistlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out', type=Path, required=True, help='New output directory outside the repo')
args = parser.parse_args()
out = args.out.resolve()
if out == Path.cwd() or Path(__file__).resolve().parents[2] in out.parents:
    parser.error('Use an output directory outside the checkout')
out.mkdir(parents=True, exist_ok=False)
for label, count in [('small', 32), ('large', 548984)]:
    data = bytes(i % 251 for i in range(count))
    encoded = base64.b64encode(data).decode('ascii')
    title = 'Offline probe ' + label
    page = '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="apple-mobile-web-app-capable" content="yes"><title>TITLE</title>
<style>body{font:20px/1.5 -apple-system,Helvetica,sans-serif;margin:24px;color:#111;background:#fff}
h1{font-size:30px}pre{font:inherit;white-space:pre-wrap;word-wrap:break-word}</style></head>
<body><h1>TITLE</h1><p>No jailbreak code. No network requests.</p>
<pre id="result" role="status">HTML loaded. Waiting for JavaScript.</pre>
<script>
(function () {
    var calls = 0;
    function run() {
        if (calls++) { return; }
        var raw = atob('DATA');
        var bytes = new Uint8Array(raw.length);
        var valid = raw.length === COUNT;
        for (var i = 0; i < raw.length; i++) {
            bytes[i] = raw.charCodeAt(i);
            if (bytes[i] !== i % 251) { valid = false; }
        }
        document.getElementById('result').textContent =
            (valid ? 'PASS' : 'FAIL') + ': JavaScript ran automatically.\\n' +
            'Verified ' + bytes.length + ' embedded bytes.\\n' +
            'Opened: ' + new Date().toISOString() + '\\n' +
            'Standalone: ' + Boolean(navigator.standalone) + '\\n' +
            'URL scheme: ' + location.protocol + '\\n' +
            'Browser online flag: ' + navigator.onLine + '\\n\\n' +
            'For physical offline proof, open this with Wi-Fi and cellular data disabled.';
    }
    window.addEventListener('load', run, false);
}());
</script></body></html>'''
    page = page.replace('TITLE', html.escape(title)).replace('DATA', encoded).replace('COUNT', str(count))
    (out / (label + '.html')).write_text(page)
    url = 'data:text/html;charset=utf-8;base64,' + base64.b64encode(page.encode()).decode()
    clip = out / ('OfflineProbe-' + label + '.webclip')
    clip.mkdir()
    with (clip / 'Info.plist').open('wb') as f:
        plistlib.dump(dict(Title=title, URL=url, FullScreen=True, IsRemovable=True), f)
    (out / (label + '-url.txt')).write_text(url)
    (out / (label + '-manifest.json')).write_text(json.dumps(dict(
        bytes=count, sha256=hashlib.sha256(data).hexdigest(), html_bytes=len(page.encode()),
        url_bytes=len(url), exploit=False, network_resources=0), indent=2) + '\n')
    print(label, 'embedded bytes:', count, 'data URL bytes:', len(url))
