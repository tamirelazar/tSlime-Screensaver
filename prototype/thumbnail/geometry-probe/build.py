#!/usr/bin/env python3
"""Build a disposable geometry extension and its matching reference image."""
from pathlib import Path
import plistlib, subprocess, shutil
root=Path(__file__).resolve().parent
out=root/'build'
out.mkdir(exist_ok=True)
def run(*args): subprocess.run([str(a) for a in args],check=True)
def bundle(path,name,ident,kind,extra):
    (path/'Contents/MacOS').mkdir(parents=True,exist_ok=True)
    (path/'Contents/Resources').mkdir(parents=True,exist_ok=True)
    shutil.copyfile(root/'../routing-probe/thumbnail.png',path/'Contents/Resources/thumbnail.png')
    data=dict(CFBundleName=name,CFBundleDisplayName=name,CFBundleIdentifier=ident,CFBundleExecutable=name,CFBundlePackageType=kind,CFBundleVersion='1',CFBundleShortVersionString='1.0',LSMinimumSystemVersion='14.0',**extra)
    with (path/'Contents/Info.plist').open('wb') as f: plistlib.dump(data,f)
    return path/'Contents/MacOS'/name
common=['xcrun','clang','-fobjc-arc','-O2','-mmacosx-version-min=14.0','-framework','Cocoa','-framework','ScreenSaver']
host=out/'Geometry Probe Host.app'
exe=bundle(host,'Geometry Probe Host','local.oozel.geometry-probe.host','APPL',dict(LSUIElement=True))
run(*common,root/'../routing-probe/Host.m','-o',exe)
appex=host/'Contents/PlugIns/Geometry Probe.appex'
exe=bundle(appex,'Geometry Probe','local.oozel.geometry-probe.host.appex','XPC!',dict(NSExtension=dict(NSExtensionPointIdentifier='com.apple.screensaver',NSExtensionPointVersion='1.0',NSExtensionPrincipalClass='RoutingProbeExtension'),ScreenSaverViewControllerClass='RoutingProbeController',SSEHasConfigureSheet=False,SSENeedsAnimationTimer=False))
run(*common,'-e','_NSExtensionMain',root/'GeometryView.m',root/'Calibration.m',root/'../routing-probe/Appex.m','-o',exe)
entitlements=out/'entitlements.plist'
with entitlements.open('wb') as f: plistlib.dump({'com.apple.security.app-sandbox':True,'com.apple.security.temporary-exception.mach-lookup.global-name':['com.apple.CARenderServer','com.apple.CoreDisplay.master','com.apple.ViewBridgeAuxiliary']},f)
run('codesign','--force','--sign','-','--entitlements',entitlements,appex)
run('codesign','--force','--sign','-',host)
run(*common,root/'Render.m',root/'Calibration.m','-o',out/'render')
run(out/'render',root/'reference.png')
print(host)
