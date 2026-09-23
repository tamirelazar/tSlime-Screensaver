#!/usr/bin/env python3
"""Build a disposable Aerial-style video-layer control. Requires ffmpeg."""
from pathlib import Path
import plistlib, shutil, subprocess

root = Path(__file__).resolve().parent
out = root / 'build'
out.mkdir(exist_ok=True)

def run(*args):
    subprocess.run([str(a) for a in args], check=True)

def bundle(path, name, ident, kind, extra):
    (path / 'Contents/MacOS').mkdir(parents=True, exist_ok=True)
    (path / 'Contents/Resources').mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / '../routing-probe/thumbnail.png', path / 'Contents/Resources/thumbnail.png')
    data = dict(CFBundleName=name, CFBundleDisplayName=name, CFBundleIdentifier=ident,
                CFBundleExecutable=name, CFBundlePackageType=kind, CFBundleVersion='1',
                CFBundleShortVersionString='1.0', LSMinimumSystemVersion='14.0', **extra)
    with (path / 'Contents/Info.plist').open('wb') as f:
        plistlib.dump(data, f)
    return path / 'Contents/MacOS' / name

common = ['xcrun', 'clang', '-fobjc-arc', '-O2', '-mmacosx-version-min=14.0',
          '-framework', 'Cocoa', '-framework', 'ScreenSaver', '-framework', 'QuartzCore', '-framework', 'AVFoundation']
host = out / 'AV Geometry Probe Host.app'
exe = bundle(host, 'AV Geometry Probe Host', 'local.oozel.av-geometry-probe.host', 'APPL', dict(LSUIElement=True))
run(*common, root / '../routing-probe/Host.m', '-o', exe)
appex = host / 'Contents/PlugIns/AV Geometry Probe.appex'
exe = bundle(appex, 'AV Geometry Probe', 'local.oozel.av-geometry-probe.host.appex', 'XPC!',
             dict(NSExtension=dict(NSExtensionPointIdentifier='com.apple.screensaver',
                  NSExtensionPointVersion='1.0', NSExtensionPrincipalClass='RoutingProbeExtension'),
                  ScreenSaverViewControllerClass='RoutingProbeController', SSEHasConfigureSheet=False,
                  SSENeedsAnimationTimer=False))
run(*common, '-e', '_NSExtensionMain', root / 'AVGeometryView.m', root / '../routing-probe/Appex.m', '-o', exe)
run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-loop', '1', '-framerate', '10',
    '-i', root / 'reference.png', '-t', '2', '-c:v', 'libx264', '-crf', '12', '-pix_fmt', 'yuv420p',
    '-vf', 'setsar=1', appex / 'Contents/Resources/calibration.mov')
run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', appex / 'Contents/Resources/calibration.mov',
    '-frames:v', '1', root / 'av-decoded-reference.png')
entitlements = out / 'av-entitlements.plist'
with entitlements.open('wb') as f:
    plistlib.dump({'com.apple.security.app-sandbox': True,
                  'com.apple.security.temporary-exception.mach-lookup.global-name':
                  ['com.apple.CARenderServer', 'com.apple.CoreDisplay.master', 'com.apple.ViewBridgeAuxiliary']}, f)
run('codesign', '--force', '--sign', '-', '--entitlements', entitlements, appex)
run('codesign', '--force', '--sign', '-', host)
print(host)
