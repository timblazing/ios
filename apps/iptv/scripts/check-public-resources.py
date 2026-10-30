#!/usr/bin/env python3
"""Reject private provisioning and macOS metadata before public packaging."""
from pathlib import Path
import sys

for root in map(Path, sys.argv[1:] or ['Resources']):
    for path in root.rglob('*'):
        if path.name == 'com.local.iptv.configuration.plist' or '.local.' in path.name:
            raise SystemExit('Private provisioning must stay outside public app resources.')
        if path.name.startswith('._') or path.name == '.DS_Store':
            raise SystemExit('Remove macOS metadata from public app resources.')
