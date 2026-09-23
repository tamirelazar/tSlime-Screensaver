#!/usr/bin/env python3
"""Generate the minimal Xcode project for this disposable ExtensionKit probe."""
from pathlib import Path
import hashlib
import plistlib

root = Path(__file__).resolve().parent
project = root / 'NativeGeometryProbe.xcodeproj'
project.mkdir(exist_ok=True)


def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


objects = {}


def add(key_name, isa, **fields):
    key = ident(key_name)
    objects[key] = dict(isa=isa, **fields)
    return key


probe = add('probe-file', 'PBXFileReference', lastKnownFileType='sourcecode.swift',
            path='Probe.swift', sourceTree='<group>')
shims = add('shims-file', 'PBXFileReference', lastKnownFileType='sourcecode.swift',
            path='CodableShims.swift', sourceTree='<group>')
settings = add('settings-file', 'PBXFileReference', lastKnownFileType='sourcecode.swift',
               path='SettingsProvider.swift', sourceTree='<group>')
runtime = add('runtime-file', 'PBXFileReference', lastKnownFileType='sourcecode.swift',
              path='RuntimeHelpers.swift', sourceTree='<group>')
host_source = add('host-file', 'PBXFileReference', lastKnownFileType='sourcecode.c.objc',
                  path='../routing-probe/Host.m', sourceTree='<group>')
image = add('image-file', 'PBXFileReference', lastKnownFileType='image.png',
            path='reference.png', sourceTree='<group>')
bridge = add('bridge-file', 'PBXFileReference', lastKnownFileType='sourcecode.c.h',
             path='PrivateBridge.h', sourceTree='<group>')
host_info = add('host-info-file', 'PBXFileReference', lastKnownFileType='text.plist.xml',
                path='HostInfo.plist', sourceTree='<group>')
ext_info = add('ext-info-file', 'PBXFileReference', lastKnownFileType='text.plist.xml',
               path='ExtensionInfo.plist', sourceTree='<group>')
entitlements = add('entitlements-file', 'PBXFileReference', lastKnownFileType='text.plist.xml',
                   path='Extension.entitlements', sourceTree='<group>')
app_product = add('app-product', 'PBXFileReference', explicitFileType='wrapper.application',
                  includeInIndex='0', path='Native Geometry Probe Host.app',
                  sourceTree='BUILT_PRODUCTS_DIR')
ext_product = add('ext-product', 'PBXFileReference', explicitFileType='wrapper.app-extension',
                  includeInIndex='0', path='NativeGeometryProbe.appex',
                  sourceTree='BUILT_PRODUCTS_DIR')

group = add('main-group', 'PBXGroup', children=[probe, shims, settings, runtime,
              host_source, image, bridge, host_info, ext_info, entitlements],
            sourceTree='<group>')
products = add('products-group', 'PBXGroup', children=[app_product, ext_product],
               name='Products', sourceTree='<group>')


def build_file(name, ref, settings=None):
    fields = dict(fileRef=ref)
    if settings: fields['settings'] = settings
    return add(name, 'PBXBuildFile', **fields)


host_sources = add('host-sources-phase', 'PBXSourcesBuildPhase',
                   buildActionMask='2147483647', files=[build_file('host-build', host_source)],
                   runOnlyForDeploymentPostprocessing='0')
ext_sources = add('ext-sources-phase', 'PBXSourcesBuildPhase',
                  buildActionMask='2147483647', files=[build_file('probe-build', probe),
                  build_file('shims-build', shims), build_file('settings-build', settings),
                  build_file('runtime-build', runtime)],
                  runOnlyForDeploymentPostprocessing='0')
ext_resources = add('ext-resources-phase', 'PBXResourcesBuildPhase',
                    buildActionMask='2147483647', files=[build_file('image-build', image)],
                    runOnlyForDeploymentPostprocessing='0')
copy_extension = add('copy-extension-phase', 'PBXCopyFilesBuildPhase',
                     buildActionMask='2147483647', dstPath='$(EXTENSIONS_FOLDER_PATH)',
                     dstSubfolderSpec='16',
                     files=[build_file('embed-extension', ext_product,
                                       dict(ATTRIBUTES=['RemoveHeadersOnCopy']))],
                     name='Embed ExtensionKit Extensions', runOnlyForDeploymentPostprocessing='0')

base = dict(SDKROOT='macosx', MACOSX_DEPLOYMENT_TARGET='26.0',
            SWIFT_VERSION='5.0', CLANG_ENABLE_MODULES='YES',
            CODE_SIGN_IDENTITY='-', CODE_SIGN_STYLE='Manual')


def config(name, extra):
    return add(name, 'XCBuildConfiguration', buildSettings=dict(base, **extra),
               name='Debug')


project_config = config('project-config', {})
host_config = config('host-config', dict(PRODUCT_BUNDLE_IDENTIFIER='local.oozel.native-wallpaper-probe.host',
                      PRODUCT_NAME='Native Geometry Probe Host',
                      INFOPLIST_FILE='HostInfo.plist', GENERATE_INFOPLIST_FILE='NO'))
extension_config = config('extension-config', dict(
    PRODUCT_BUNDLE_IDENTIFIER='local.oozel.native-wallpaper-probe.host.extension',
    PRODUCT_NAME='NativeGeometryProbe', PRODUCT_MODULE_NAME='NativeGeometryProbe',
    INFOPLIST_FILE='ExtensionInfo.plist', GENERATE_INFOPLIST_FILE='NO',
    CODE_SIGN_ENTITLEMENTS='Extension.entitlements', ENABLE_APP_SANDBOX='YES',
    APPLICATION_EXTENSION_API_ONLY='YES', SWIFT_OBJC_BRIDGING_HEADER='PrivateBridge.h',
    LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/../Frameworks',
                             '@executable_path/../../../../Frameworks']))


def configs(name, config_id):
    return add(name, 'XCConfigurationList', buildConfigurations=[config_id],
               defaultConfigurationIsVisible='0', defaultConfigurationName='Debug')


project_configs = configs('project-config-list', project_config)
host_configs = configs('host-config-list', host_config)
extension_configs = configs('ext-config-list', extension_config)

extension_target = add('extension-target', 'PBXNativeTarget',
                       buildConfigurationList=extension_configs,
                       buildPhases=[ext_sources, ext_resources], buildRules=[],
                       dependencies=[], name='NativeGeometryProbe',
                       productName='NativeGeometryProbe', productReference=ext_product,
                       productType='com.apple.product-type.app-extension')
proxy = add('extension-proxy', 'PBXContainerItemProxy', containerPortal=ident('project'),
            proxyType='1', remoteGlobalIDString=extension_target,
            remoteInfo='NativeGeometryProbe')
dependency = add('extension-dependency', 'PBXTargetDependency', target=extension_target,
                 targetProxy=proxy)
host_target = add('host-target', 'PBXNativeTarget', buildConfigurationList=host_configs,
                  buildPhases=[host_sources, copy_extension], buildRules=[],
                  dependencies=[dependency], name='NativeGeometryProbeHost',
                  productName='Native Geometry Probe Host', productReference=app_product,
                  productType='com.apple.product-type.application')
project_id = add('project', 'PBXProject', attributes=dict(LastUpgradeCheck='2660'),
                 buildConfigurationList=project_configs, compatibilityVersion='Xcode 16.0',
                 developmentRegion='en', hasScannedForEncodings='0',
                 knownRegions=['en'], mainGroup=group, productRefGroup=products,
                 projectDirPath='', projectRoot='', targets=[host_target, extension_target])

with (project / 'project.pbxproj').open('wb') as file:
    plistlib.dump(dict(archiveVersion='1', classes={}, objectVersion='77',
                      objects=objects, rootObject=project_id), file)

with (root / 'HostInfo.plist').open('wb') as file:
    plistlib.dump(dict(CFBundleName='Native Geometry Probe Host',
                       CFBundleDisplayName='Native Geometry Probe Host',
                       CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)',
                       CFBundleExecutable='$(EXECUTABLE_NAME)', CFBundlePackageType='APPL',
                       CFBundleVersion='1', CFBundleShortVersionString='1.0',
                       LSMinimumSystemVersion='26.0', LSUIElement=True), file)

with (root / 'ExtensionInfo.plist').open('wb') as file:
    plistlib.dump(dict(CFBundleName='NativeGeometryProbe',
                       CFBundleDisplayName='Native Geometry Probe',
                       CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)',
                       CFBundleExecutable='$(EXECUTABLE_NAME)', CFBundlePackageType='XPC!',
                       CFBundleVersion='1', CFBundleShortVersionString='1.0',
                       LSMinimumSystemVersion='26.0',
                       EXAppExtensionAttributes=dict(EXExtensionPointIdentifier='com.apple.wallpaper')), file)

with (root / 'Extension.entitlements').open('wb') as file:
    plistlib.dump({'com.apple.security.app-sandbox': True,
                   'com.apple.security.cs.disable-library-validation': True,
                   'com.apple.security.temporary-exception.mach-lookup.global-name':
                   ['com.apple.CARenderServer', 'com.apple.CoreDisplay.master',
                    'com.apple.ViewBridgeAuxiliary']}, file)

print(project)
