#!/usr/bin/env python3
"""Build two isolated test savers; does not install or select either one."""
import pathlib, plistlib, subprocess, shutil
root = pathlib.Path(__file__).resolve().parent
out = root / 'build'
out.mkdir(exist_ok=True)
def run(*args): subprocess.run(args, check=True)
def bundle(path, name, ident, kind, extra=None):
    (path / 'Contents/MacOS').mkdir(parents=True, exist_ok=True)
    (path / 'Contents/Resources').mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / 'thumbnail.png', path / 'Contents/Resources/thumbnail.png')
    data = dict(CFBundleName=name, CFBundleDisplayName=name, CFBundleIdentifier=ident,
                CFBundleExecutable=name, CFBundlePackageType=kind, CFBundleVersion='1',
                CFBundleShortVersionString='1.0', LSMinimumSystemVersion='14.0')
    data.update(extra or {})
    with (path / 'Contents/Info.plist').open('wb') as f: plistlib.dump(data, f)
    return str(path / 'Contents/MacOS' / name)
common = ['xcrun', 'clang', '-fobjc-arc', '-O2', '-mmacosx-version-min=14.0', '-framework', 'Cocoa', '-framework', 'ScreenSaver']
legacy = out / 'Routing Probe Legacy.saver'
exe = bundle(legacy, 'Routing Probe Legacy', 'local.oozel.routing-probe.legacy', 'BNDL', {'NSPrincipalClass':'RoutingProbeView'})
run(*common, '-bundle', str(root/'ProbeView.m'), '-o', exe)
run('codesign', '--force', '--sign', '-', str(legacy))
host = out / 'Routing Probe Host.app'
exe = bundle(host, 'Routing Probe Host', 'local.oozel.routing-probe.host', 'APPL', {'LSUIElement':True})
run(*common, str(root/'Host.m'), '-o', exe)
for variant in ['Appex', 'Zero']:
    name = 'Routing Probe ' + variant
    appex = host / 'Contents/PlugIns' / (name+'.appex')
    exe = bundle(appex, name, 'local.oozel.routing-probe.host.'+variant.lower(), 'XPC!', {
        'NSExtension': {'NSExtensionPointIdentifier':'com.apple.screensaver', 'NSExtensionPointVersion':'1.0', 'NSExtensionPrincipalClass':'RoutingProbeExtension'},
        'ScreenSaverViewControllerClass':'RoutingProbeController', 'SSEHasConfigureSheet':False, 'SSENeedsAnimationTimer':False})
    flags = ['-DPROBE_KIND=@"'+variant.upper()+'"']
    if variant == 'Zero': flags += ['-DZERO_FRAME=1']
    run(*common, *flags, '-e', '_NSExtensionMain', str(root/'ProbeView.m'), str(root/'Appex.m'), '-o', exe)
    entitlements = out / 'entitlements.plist'
    with entitlements.open('wb') as f: plistlib.dump({'com.apple.security.app-sandbox':True, 'com.apple.security.temporary-exception.mach-lookup.global-name':['com.apple.CARenderServer','com.apple.CoreDisplay.master','com.apple.ViewBridgeAuxiliary']}, f)
    run('codesign', '--force', '--sign', '-', '--entitlements', str(entitlements), str(appex))
run('codesign', '--force', '--sign', '-', str(host))
print('Built:', legacy, host, sep='\n')
