#!/usr/bin/env python3
"""Validate public release identity, privacy exclusions, resources, and hashes."""
import hashlib
import io
from pathlib import Path
import plistlib
import subprocess
import tarfile
import zipfile

root = Path(__file__).resolve().parents[1]
version = next(x.split(':', 1)[1].strip() for x in (root / 'control').read_text().splitlines() if x.startswith('Version:'))
ipa = root / 'dist' / ('T3Code-' + version + '.ipa')
deb = root / 'packages' / ('com.local.t3mini_' + version + '_iphoneos-arm.deb')
for archive in [ipa, deb]:
    assert archive.exists(), str(archive)
with zipfile.ZipFile(ipa) as z:
    names = z.namelist()
    assert not any('Pairing.local' in n or '.local.' in n for n in names), 'Private provisioning in IPA'
    info = plistlib.loads(z.read('Payload/T3Mini.app/Info.plist'))
    assert info['CFBundleIdentifier'] == 'com.local.t3mini'
    assert info['CFBundleDisplayName'] == 'T3 Code'
    assert info['CFBundleVersion'] == info['CFBundleShortVersionString'] == version
    assert info['MinimumOSVersion'] == '10.0'
    for resource in ['index.html', 'chat.js', 'chat.css', 'picker.js', 'picker.css', 'DMSans-Regular.ttf', 'DMSans-Medium.ttf', 'DMSans-Bold.ttf', 'DMSans-OFL.txt']:
        assert 'Payload/T3Mini.app/' + resource in names, resource
        assert z.read('Payload/T3Mini.app/' + resource) == (root / 'Resources' / resource).read_bytes(), 'Stale resource: ' + resource
members = subprocess.check_output(['ar', 't', str(deb)], text=True).splitlines()
data_member = next(x for x in members if x.startswith('data.tar'))
data = subprocess.check_output(['ar', 'p', str(deb), data_member])
with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as tar:
    assert not any('Pairing.local' in n or '.local.' in n for n in tar.getnames()), 'Private provisioning in DEB'
    member = next(x for x in tar.getmembers() if x.name.endswith('/T3Mini.app/Info.plist'))
    assert plistlib.loads(tar.extractfile(member).read()) == info
for line in (root / 'dist/SHA256SUMS').read_text().splitlines():
    digest, name = line.split(None, 1)
    assert hashlib.sha256((root / 'dist' / name).read_bytes()).hexdigest() == digest, name
print('Public IPA/DEB identity, iOS 10 metadata, bundled UI/fonts, private-file exclusions and all checksums passed.')
