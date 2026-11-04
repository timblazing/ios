#!/usr/bin/env python3
"""Sign a harmless canary using its own Apple development profile; never installs it."""
import argparse
import datetime
import hashlib
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import zipfile

BUNDLE_IDS = {'com.local.launchcanary.legacy', 'com.local.launchcanary.modern'}


def validate_profile(profile, bundle_id, udid, identity, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    if bundle_id not in BUNDLE_IDS:
        raise ValueError('Only the two launch canaries may be signed')
    if not profile.get('CreationDate') or profile['CreationDate'] > now:
        raise ValueError('Profile is not yet valid')
    if not profile.get('ExpirationDate') or profile['ExpirationDate'] <= now:
        raise ValueError('Profile has expired')
    if udid not in profile.get('ProvisionedDevices', []):
        raise ValueError('Profile does not include the target iPad')
    entitlements = profile.get('Entitlements', {})
    prefixes = profile.get('ApplicationIdentifierPrefix', [])
    if not any(entitlements.get('application-identifier') == prefix + '.' + bundle_id for prefix in prefixes):
        raise ValueError('Profile must authorize this exact canary ID; unrelated/wildcard profiles are refused')
    team = entitlements.get('com.apple.developer.team-identifier')
    if not team or team not in profile.get('TeamIdentifier', []):
        raise ValueError('Profile team does not match its entitlements')
    certificates = {hashlib.sha1(cert).hexdigest().upper() for cert in profile.get('DeveloperCertificates', [])}
    if identity.upper() not in certificates:
        raise ValueError('Signing certificate is not authorized by this profile')
    if entitlements.get('get-task-allow') is not True:
        raise ValueError('Expected an Apple development profile')
    return {key: entitlements[key] for key in ('application-identifier',
            'com.apple.developer.team-identifier', 'get-task-allow', 'keychain-access-groups') if key in entitlements}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=pathlib.Path, required=True)
    parser.add_argument('--profile', type=pathlib.Path, required=True)
    parser.add_argument('--identity', required=True, help='SHA-1 certificate fingerprint from security find-identity')
    parser.add_argument('--udid-file', type=pathlib.Path, required=True, help='Private file containing target iPad UDID')
    parser.add_argument('--out', type=pathlib.Path, required=True, help='New output directory outside checkout')
    args = parser.parse_args()
    out = args.out.resolve()
    repo = pathlib.Path(__file__).resolve().parents[2]
    if out == repo or repo in out.parents:
        parser.error('Keep signed apps/profiles/device information outside Git')
    info = plistlib.loads((args.app / 'Info.plist').read_bytes())
    profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(args.profile)], stderr=subprocess.DEVNULL))
    try:
        entitlements = validate_profile(profile, info['CFBundleIdentifier'], args.udid_file.read_text().strip(), args.identity)
    except ValueError as error:
        parser.error(str(error))
    binary_name = info['CFBundleExecutable']
    before = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(args.app / binary_name)], text=True)
    expected_sdk = 'sdk 9.3' if info['CFBundleIdentifier'].endswith('.legacy') else 'sdk 16.4'
    if expected_sdk not in before or 'version 10.0' not in before or 'LC_VERSION_MIN_IPHONEOS' not in before:
        parser.error('Unexpected input SDK/minimum OS metadata; inspect before signing')
    out.mkdir(parents=True, exist_ok=False)
    out.chmod(0o700)
    app = out / 'Payload' / 'LaunchCanary.app'
    shutil.copytree(args.app, app)
    shutil.copyfile(args.profile, app / 'embedded.mobileprovision')
    with tempfile.TemporaryDirectory(prefix='canary-entitlements-') as temporary:
        ent = pathlib.Path(temporary) / 'entitlements.plist'
        ent.write_bytes(plistlib.dumps(entitlements))
        subprocess.run(['codesign', '--force', '--sign', args.identity, '--entitlements', str(ent),
                        '--generate-entitlement-der', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', '-R', 'anchor apple generic', str(app)], check=True)
    after = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(app / binary_name)], text=True)
    # vtool prefixes its report with the input filename.
    if before.splitlines()[1:] != after.splitlines()[1:]:
        raise RuntimeError('Signing changed SDK metadata; do not install')
    signed = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL))
    if signed != entitlements:
        raise RuntimeError('Final signed entitlements do not match the validated profile')
    with tempfile.TemporaryDirectory(prefix='canary-certificate-') as temporary:
        prefix = str(pathlib.Path(temporary) / 'cert')
        subprocess.run(['codesign', '-d', '--extract-certificates', prefix, str(app)], check=True, capture_output=True)
        fingerprint = hashlib.sha1(pathlib.Path(prefix + '0').read_bytes()).hexdigest().upper()
        if fingerprint != args.identity.upper():
            raise RuntimeError('Final signature has an unexpected certificate')
    ipa = out / ('canary-' + info['CFBundleIdentifier'].rsplit('.', 1)[1] + '-DEVELOPMENT.ipa')
    with zipfile.ZipFile(ipa, 'w', zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(app.rglob('*')):
            if file.is_file():
                archive.write(file, file.relative_to(out))
    print(after)
    print('Validated dedicated profile, target enrollment, signing certificate, entitlements and unchanged SDK metadata.')
    print('Profile expiry (UTC):', profile['ExpirationDate'].isoformat())
    print('IPA:', ipa)
    print('Stock-boot execution still requires physical proof; this command never installs or launches.')


if __name__ == '__main__':
    main()
