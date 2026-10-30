#!/usr/bin/env python3
"""Package pinned TNS into an offline WebClip. Default is a non-executing check page."""
import argparse
import base64
import hashlib
import html
import json
from pathlib import Path
import plistlib
import uuid
import zlib

PIN = '1ab104d48df7064cba3ea2f7650ae1e3e31c29be'
HASHES = {
    'payload': '398e6f2340e791c0fe73b8bc4c0c25cffcb019f23078b0e5e3940a8f66678cc8',
    'root/js/utils.js': 'd8eecd88560be3c650eb80d86f03d898d228957666b2079e016c05757f754b0d',
    'root/js/int64.js': '00e1aa9e8e7fa86aa65b32c6813ca5c3e14fe43b3a9c32776e514e6b830dd0ca',
    'root/js/spyware.js': '00863276397959ae962a35032ee20b6b8a55053d20582f4afc0d79e1501c8269',
    'root/js/pwn.js': 'b7d3c3b64df65fb17efb01c865277ef6bbe051b50c78e00d42999432b78657a7',
    'LICENSE': 'cbafcce530d29773d72974920fb902d995f725cfeea8484788414919ac7cbbe5',
}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, required=True, help='Checkout of the pinned LukeZGD/tns-sockport revision')
parser.add_argument('--out', type=Path, required=True, help='New directory outside the repo')
parser.add_argument('--live', action='store_true', help='Enable an explicit Run once button; NEVER auto-runs')
args = parser.parse_args()
out = args.out.resolve()
if out == Path.cwd() or Path(__file__).resolve().parents[2] in out.parents:
    parser.error('Use an output directory outside the checkout')
files = {}
for name, expected in HASHES.items():
    data = (args.source / name).read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        parser.error('Pinned upstream hash mismatch: ' + name)
    files[name] = data
scripts = [files[name].decode() for name in ['root/js/utils.js', 'root/js/int64.js', 'root/js/spyware.js', 'root/js/pwn.js']]
old_fail = """        alert('FAIL: ' + x);
        location.reload();
        throw null;"""
if scripts[2].count(old_fail) != 1:
    parser.error('Upstream failure handler did not match')
scripts[2] = scripts[2].replace(old_fail, '        throw new Error(String(x));')
# Keep pwn() unchanged. Remove the network-fetching go() adapter in favor of embedded bytes.
marker = '\nfunction go()\n'
if scripts[3].count(marker) != 1:
    parser.error('Upstream network adapter boundary did not match')
scripts[3] = scripts[3].split(marker)[0]
controller = Path(__file__).with_name('offline-tns-controller.js').read_text()
config = dict(checkOnly=not args.live, payload=base64.b64encode(files['payload']).decode(),
              bytes=len(files['payload']), crc32=zlib.crc32(files['payload']))
javascript = '\n;\n'.join(scripts + ['var TNS_CONFIG = ' + json.dumps(config) + ';', controller])
for forbidden in ['</script', 'location.reload(', 'XMLHttpRequest', 'fetch(']:
    if forbidden in javascript:
        parser.error('Unexpected active markup, retry or network adapter: ' + forbidden)
title = 'Offline TNS' if args.live else 'TNS Offline Check'
intro = ('This page can run the TNS exploit. Use only after a normal reboot, while unjailbroken.' if args.live else
         'This page checks the embedded TNS assets. It cannot start the exploit.')
page = '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="apple-mobile-web-app-capable" content="yes"><title>__TITLE__</title>
<style>body{font:20px/1.5 -apple-system,Helvetica,sans-serif;margin:24px;color:#111;background:#fff}
h1{font-size:30px}pre{font:inherit;white-space:pre-wrap;word-wrap:break-word}
button{font:inherit;min-height:48px;padding:8px 16px}</style></head><body>
<h1>__TITLE__</h1><p>__INTRO__</p><pre id="result" role="status">Checking embedded assets…</pre>
<button id="run" disabled>Run once after reboot</button>
<script>__JS__</script>
<details><summary>Upstream license</summary><pre>__LICENSE__</pre></details></body></html>'''
page = page.replace('__TITLE__', title).replace('__INTRO__', intro).replace('__JS__', javascript)
page = page.replace('__LICENSE__', html.escape(files['LICENSE'].decode()))
url = 'data:text/html;charset=utf-8;base64,' + base64.b64encode(page.encode()).decode()
identifier = 'com.local.offlinetns.' + ('live' if args.live else 'check')
payload = dict(PayloadType='com.apple.webClip.managed', PayloadVersion=1,
               PayloadIdentifier=identifier + '.webclip', PayloadUUID=str(uuid.uuid4()),
               PayloadDisplayName=title, Label=title, URL=url, FullScreen=True, IsRemovable=True)
profile = dict(PayloadType='Configuration', PayloadVersion=1, PayloadIdentifier=identifier,
               PayloadUUID=str(uuid.uuid4()), PayloadDisplayName=title,
               PayloadDescription=intro, PayloadContent=[payload])
out.mkdir(parents=True, exist_ok=False)
(out / 'index.html').write_text(page)
(out / 'controller-test-config.json').write_text(json.dumps(config))
with (out / 'tns.mobileconfig').open('wb') as f:
    plistlib.dump(profile, f)
(out / 'upstream-LICENSE.txt').write_bytes(files['LICENSE'])
(out / 'manifest.json').write_text(json.dumps(dict(upstream=PIN, hashes=HASHES, check_only=not args.live,
                                                 auto_start=False, data_url_bytes=len(url)), indent=2) + '\n')
print(title, 'data URL bytes:', len(url), 'check only:', not args.live, 'auto-start: false')
