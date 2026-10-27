#!/usr/bin/env python3
"""Inline a <symbol> sprite into Resources/index.html from Tabler outline icons (MIT).
Usage: make-icons.py <path to @tabler/icons package>/icons"""
import re
import sys
from pathlib import Path
NAMES = {'settings': 'settings', 'search': 'search', 'compose': 'edit', 'sidebar': 'layout-sidebar',
         'arrow-up': 'arrow-up', 'x': 'x', 'check': 'check', 'chevron-down': 'chevron-down',
         'chevron-right': 'chevron-right', 'refresh': 'refresh', 'terminal': 'terminal-2', 'eye': 'eye',
         'brain': 'brain', 'globe': 'world', 'tool': 'tool', 'file-search': 'file-search', 'pencil': 'pencil',
         'list': 'list-check', 'working': 'circle-dashed', 'alert': 'alert-circle', 'shield': 'shield-exclamation',
         'question': 'message-question', 'offline': 'wifi-off', 'laptop': 'device-laptop', 'done': 'circle-check',
         'qr': 'qrcode', 'trash': 'trash', 'arrow-down': 'arrow-down', 'sparkles': 'sparkles'}
icons = Path(sys.argv[1])
out = []
for key, name in sorted(NAMES.items()):
    svg = (icons / 'outline' / (name + '.svg')).read_text()
    body = re.search(r'<svg[^>]*>(.*)</svg>', svg, re.S).group(1)
    body = re.sub(r'<path stroke="none" d="M0 0h24v24H0z" fill="none"\s*/>', '', body)
    out.append('<symbol id="i-%s" viewBox="0 0 24 24">%s</symbol>' % (key, re.sub(r'\s+', ' ', body).strip()))
stop = '<symbol id="i-stop" viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2.5" fill="currentColor" stroke="none"/></symbol>'
# Inline, not an external file: <use> with external references is unreliable in iOS 10 WKWebView.
html = Path(__file__).resolve().parent.parent / 'Resources' / 'index.html'
sprite = '<svg xmlns="http://www.w3.org/2000/svg" class="sprite" width="0" height="0" aria-hidden="true">' + ''.join(out) + stop + '</svg>'
html.write_text(re.sub(r'<!--icons-->.*?<!--/icons-->', lambda m: '<!--icons-->' + sprite + '<!--/icons-->', html.read_text(), flags=re.S))
