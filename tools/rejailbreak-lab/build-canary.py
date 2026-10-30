#!/usr/bin/env python3
"""Build two harmless canaries. Outputs are ad-hoc signed, NOT stock-boot capable."""
import argparse
import pathlib
import plistlib
import subprocess
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out', type=pathlib.Path, required=True, help='New output directory outside the repo')
args = parser.parse_args()
out = args.out.resolve()
if out == pathlib.Path.cwd() or pathlib.Path(__file__).resolve().parents[2] in out.parents:
    parser.error('Use an output directory outside the checkout')
out.mkdir(parents=True, exist_ok=False)
sdk = pathlib.Path.home() / 'theos/sdks/iPhoneOS16.5.sdk'
source = pathlib.Path(__file__).with_name('LaunchCanary.m')
for variant in ('modern', 'legacy'):
    app = out / variant / 'Payload' / 'LaunchCanary.app'
    app.mkdir(parents=True)
    binary = app / 'LaunchCanary'
    subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-ios10.0', '-isysroot', str(sdk),
                    '-fobjc-arc', '-fno-exceptions', '-fno-objc-exceptions', '-Wall', '-Wextra',
                    '-framework', 'Foundation', '-framework', 'UIKit', str(source), '-o', str(binary)], check=True)
    if variant == 'legacy':
        patched = app / 'LaunchCanary.patched'
        subprocess.run(['xcrun', 'vtool', '-set-version-min', 'ios', '10.0', '9.3', '-replace',
                        '-output', str(patched), str(binary)], check=True)
        patched.replace(binary)
        binary.chmod(0o755)
    info = dict(CFBundleExecutable='LaunchCanary', CFBundleIdentifier='com.local.launchcanary.' + variant,
                CFBundleName='Launch Canary', CFBundleDisplayName='Canary ' + variant,
                CFBundlePackageType='APPL', CFBundleVersion='1', CFBundleShortVersionString='0.1',
                MinimumOSVersion='10.0', UIDeviceFamily=[2], UIBackgroundModes=['audio', 'voip'],
                UIFileSharingEnabled=True, LSRequiresIPhoneOS=True,
                UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft',
                                                 'UIInterfaceOrientationLandscapeRight'])
    with (app / 'Info.plist').open('wb') as f:
        plistlib.dump(info, f)
    # This signature is deliberately NOT represented as a valid Apple development signature.
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
    subprocess.run(['xcrun', 'vtool', '-show-build', str(binary)], check=True)
    with zipfile.ZipFile(out / ('canary-' + variant + '-ADHOC.ipa'), 'w', zipfile.ZIP_DEFLATED) as z:
        for f in sorted(app.rglob('*')):
            if f.is_file():
                z.write(f, f.relative_to(app.parent.parent))
print('Builds complete. Stock-boot test requires valid Apple signing, matching profiles and the iPad UDID.')
