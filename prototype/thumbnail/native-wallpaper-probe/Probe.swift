// Disposable native Wallpaper extension calibration. XPC shims and settings
// model are adapted from Aerial 2fcb2b8; see AERIAL-LICENSE.
import AppKit
import ExtensionFoundation
import Foundation
import ImageIO
import os
import QuartzCore

private let probeLogger = Logger(subsystem: "local.oozel.native-wallpaper-probe", category: "geometry")

func debugLog(_ message: String) {
    probeLogger.notice("\(message, privacy: .public)")
}

private struct Destination {
    let size: CGSize
    let scale: CGFloat
    let displayID: UInt32?
    let isPreview: Bool
    let mode: String
}

private func destination(from request: Any?) -> Destination {
    let inner = (request as? NSObject).flatMap { Mirror(reflecting: $0).children.first?.value }
    var size = CGSize(width: 1920, height: 1080)
    var scale: CGFloat = 2
    var displayID: UInt32?
    var isPreview = false
    var mode = "?"
    if let inner {
        for field in Mirror(reflecting: inner).children {
            switch field.label {
            case "destination":
                for geometry in Mirror(reflecting: field.value).children {
                    switch geometry.label {
                    case "size": size = geometry.value as? CGSize ?? size
                    case "scaleFactor": scale = geometry.value as? CGFloat ?? scale
                    case "directDisplayID": displayID = geometry.value as? UInt32
                    default: break
                    }
                }
            case "isPreview": isPreview = field.value as? Bool ?? false
            case "presentationMode": mode = String(describing: field.value)
            default: break
            }
        }
    }
    return Destination(size: size, scale: scale, displayID: displayID,
                       isPreview: isPreview, mode: mode)
}

private struct Surface {
    let context: CAContext
    let root: CALayer
    let image: CALayer
    let label: CATextLayer
}

// Keep contexts alive across WallpaperAgent's connection churn.
private var surfaces: [String: Surface] = [:]
private var serial = 0

private func idString(_ id: Any?) -> String {
    guard let id else { return "nil" }
    let value = String(describing: Mirror(reflecting: id).children.first?.value ?? id)
    if let range = value.range(of: "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}",
                               options: .regularExpression) {
        return String(value[range])
    }
    return value
}

@objc final class ProbeHandler: NSObject {
    @objc func acquire(withId id: Any?, request: Any?,
                       reply: @escaping (Any?, Error?) -> Void) {
        serial += 1
        let number = serial
        let dest = destination(from: request)
        let key = idString(id)
        let marker = "A\(number) P\(dest.isPreview ? 1 : 0) \(dest.mode)"
        debugLog("ACQUIRE \(marker) id=\(key) destination=\(dest.size) scale=\(dest.scale) displayID=\(dest.displayID.map(String.init) ?? "nil")")

        var options: [String: Any] = ["contentsScale": dest.scale]
        if let displayID = dest.displayID { options["displayId"] = displayID }
        guard let context = CAContext.remoteContext(withOptions: options) as? CAContext,
              context.contextId != 0 else {
            reply(nil, NSError(domain: "NativeGeometryProbe", code: 1))
            return
        }

        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: dest.size)
        root.contentsScale = dest.scale
        root.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        let image = CALayer()
        image.frame = root.bounds
        image.contentsScale = dest.scale
        image.contentsGravity = .resizeAspect
        if let url = Bundle.main.url(forResource: "reference", withExtension: "png"),
           let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            image.contents = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        root.addSublayer(image)

        let label = CATextLayer()
        label.string = marker
        label.fontSize = 44
        label.alignmentMode = .center
        label.foregroundColor = CGColor(red: 1, green: 1, blue: 0, alpha: 1)
        label.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.9)
        label.contentsScale = dest.scale
        label.frame = CGRect(x: dest.size.width * 0.25, y: dest.size.height * 0.45,
                             width: dest.size.width * 0.5, height: 60)
        root.addSublayer(label)

        context.layer = root
        CATransaction.flush()
        guard let response = createRemoteContextXPC(contextId: context.contextId) else {
            reply(nil, NSError(domain: "NativeGeometryProbe", code: 2))
            return
        }
        surfaces[key] = Surface(context: context, root: root, image: image, label: label)
        debugLog("READY \(marker) context=\(context.contextId) options=\(options) root=\(root.frame)@\(root.contentsScale) image=\(image.frame)@\(image.contentsScale) gravity=\(image.contentsGravity.rawValue)")
        reply(response, nil)
    }

    @objc func update(withId id: Any?, request: Any?, reply: @escaping (Error?) -> Void) {
        let key = idString(id)
        let dest = destination(from: request)
        if let surface = surfaces[key] {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            surface.root.frame = CGRect(origin: .zero, size: dest.size)
            surface.root.contentsScale = dest.scale
            surface.image.frame = surface.root.bounds
            surface.image.contentsScale = dest.scale
            surface.label.contentsScale = dest.scale
            surface.label.frame = CGRect(x: dest.size.width * 0.25, y: dest.size.height * 0.45,
                                         width: dest.size.width * 0.5, height: 60)
            CATransaction.commit()
            CATransaction.flush()
            debugLog("UPDATE id=\(key) destination=\(dest.size)@\(dest.scale) root=\(surface.root.frame) image=\(surface.image.frame)")
        } else {
            debugLog("UPDATE missing id=\(key) destination=\(dest.size)@\(dest.scale)")
        }
        reply(nil)
    }

    @objc func invalidate(withId id: Any?, reply: @escaping (Error?) -> Void) {
        let key = idString(id)
        surfaces.removeValue(forKey: key)
        debugLog("INVALIDATE id=\(key)")
        reply(nil)
    }

    @objc func provideSettingsViewModels(withContentTypes types: Any?,
                                         reply: @escaping (Any?, Error?) -> Void) {
        Task {
            let models = await buildSettingsViewModelsXPC()
            debugLog("SETTINGS models=\(models == nil ? "nil" : "ready")")
            reply(models, models == nil ? NSError(domain: "NativeGeometryProbe", code: 3) : nil)
        }
    }

    @objc func snapshot(withId id: Any?, reply: @escaping (Any?, Error?) -> Void) {
        reply(nil, nil)
    }

    @objc func addChoiceRequest(withChoiceRequest request: Any?, onBehalfOfProcess process: Any?,
                                reply: @escaping (Any?, Error?) -> Void) {
        reply(nil, nil)
    }

    @objc func removeChoiceRequest(withChoiceRequest request: Any?,
                                   reply: @escaping (Error?) -> Void) { reply(nil) }

    @objc func selectedChoicesDidChange(for id: Any?,
                                        reply: @escaping (Error?) -> Void) { reply(nil) }

    @objc func invokeContextMenuAction(withMenuItemID item: Any?, groupItemID group: Any?,
                                       reply: @escaping (Error?) -> Void) { reply(nil) }

    @objc func isChoiceDownloaded(with choice: Any?,
                                  reply: @escaping (Bool, Error?) -> Void) { reply(true, nil) }

    @objc func download(withChoiceID choice: Any?, reply: @escaping (Error?) -> Void) -> Any? {
        reply(nil)
        return nil
    }

    @objc func pauseDownload(for choice: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    @objc func cancelDownload(for choice: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    @objc func resumeDownload(for choice: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }
    @objc func removeDownload(for choice: Any?, reply: @escaping (Error?) -> Void) { reply(nil) }

    @objc func migrateSelectedChoice(for id: Any?,
                                     reply: @escaping (Any?, Error?) -> Void) { reply(nil, nil) }
    @objc func migrate(from old: Any?, to new: Any?,
                       reply: @escaping (Error?) -> Void) { reply(nil) }
    @objc func skipShuffledContent(withId id: Any?,
                                   reply: @escaping (Error?) -> Void) { reply(nil) }
    @objc func canSkipShuffledContent(withId id: Any?,
                                      reply: @escaping (Bool, Error?) -> Void) { reply(false, nil) }
    @objc func handleDebugRequest(for request: Any?,
                                  reply: @escaping (Any?, Error?) -> Void) { reply(nil, nil) }
    @objc func handleNotification(withNamed name: Any?,
                                  reply: @escaping (Error?) -> Void) { reply(nil) }
}

struct ProbeConfig: AppExtensionConfiguration {
    func accept(connection: NSXPCConnection) -> Bool {
        let interface = NSXPCInterface(with: WallpaperExtensionXPCProtocol.self)
        let names = ["WallpaperIDXPC", "WallpaperCreationRequestXPC",
                     "WallpaperUpdateRequestXPC", "WallpaperRemoteContextXPC",
                     "WallpaperSnapshotXPC", "WallpaperContentTypeSetXPC",
                     "WallpaperSettingsViewModelsXPC", "WallpaperChoiceIDXPC",
                     "WallpaperChoiceIDsXPC", "WallpaperExtensionChoiceRequestXPC",
                     "WallpaperChoiceRequestAdditionResultXPC", "WallpaperDebugRequestXPC",
                     "WallpaperDebugResponseXPC", "WallpaperMigrationVersionXPC",
                     "AuditTokenXPC"]
        let types = NSMutableSet()
        for name in names { if let cls = objc_getClass(name) { types.add(cls) } }
        for cls: AnyClass in [NSString.self, NSNumber.self, NSData.self, NSArray.self,
                              NSDictionary.self, NSURL.self, NSError.self] { types.add(cls) }
        let classes = Set(types.compactMap { $0 as? AnyHashable })
        let selectors: [(Selector, Int, Bool)] = [
            (#selector(ProbeHandler.acquire(withId:request:reply:)), 0, false),
            (#selector(ProbeHandler.acquire(withId:request:reply:)), 1, false),
            (#selector(ProbeHandler.acquire(withId:request:reply:)), 0, true),
            (#selector(ProbeHandler.update(withId:request:reply:)), 0, false),
            (#selector(ProbeHandler.update(withId:request:reply:)), 1, false),
            (#selector(ProbeHandler.invalidate(withId:reply:)), 0, false),
            (#selector(ProbeHandler.snapshot(withId:reply:)), 0, false),
            (#selector(ProbeHandler.snapshot(withId:reply:)), 0, true),
            (#selector(ProbeHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, false),
            (#selector(ProbeHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, true),
            (#selector(ProbeHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, false),
            (#selector(ProbeHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 1, false),
            (#selector(ProbeHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, true),
            (#selector(ProbeHandler.removeChoiceRequest(withChoiceRequest:reply:)), 0, false),
            (#selector(ProbeHandler.selectedChoicesDidChange(for:reply:)), 0, false),
            (#selector(ProbeHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 0, false),
            (#selector(ProbeHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 1, false),
            (#selector(ProbeHandler.isChoiceDownloaded(with:reply:)), 0, false),
            (#selector(ProbeHandler.download(withChoiceID:reply:)), 0, false),
            (#selector(ProbeHandler.pauseDownload(for:reply:)), 0, false),
            (#selector(ProbeHandler.cancelDownload(for:reply:)), 0, false),
            (#selector(ProbeHandler.resumeDownload(for:reply:)), 0, false),
            (#selector(ProbeHandler.removeDownload(for:reply:)), 0, false),
            (#selector(ProbeHandler.migrateSelectedChoice(for:reply:)), 0, false),
            (#selector(ProbeHandler.migrateSelectedChoice(for:reply:)), 0, true),
            (#selector(ProbeHandler.migrate(from:to:reply:)), 0, false),
            (#selector(ProbeHandler.migrate(from:to:reply:)), 1, false),
            (#selector(ProbeHandler.skipShuffledContent(withId:reply:)), 0, false),
            (#selector(ProbeHandler.canSkipShuffledContent(withId:reply:)), 0, false),
            (#selector(ProbeHandler.handleDebugRequest(for:reply:)), 0, false),
            (#selector(ProbeHandler.handleDebugRequest(for:reply:)), 0, true),
            (#selector(ProbeHandler.handleNotification(withNamed:reply:)), 0, false),
        ]
        for (selector, index, reply) in selectors {
            interface.setClasses(classes, for: selector, argumentIndex: index, ofReply: reply)
        }
        connection.exportedInterface = interface
        connection.exportedObject = ProbeHandler()
        connection.remoteObjectInterface = NSXPCInterface(with: WallpaperExtensionProxyXPCProtocol.self)
        connection.resume()
        debugLog("XPC accepted pid=\(connection.processIdentifier)")
        return true
    }
}

@main final class NativeGeometryProbe: NSObject, AppExtension {
    override required init() {
        super.init()
        _ = dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_NOW)
        debugLog("INIT pid=\(ProcessInfo.processInfo.processIdentifier)")
    }

    var configuration: some AppExtensionConfiguration { ProbeConfig() }
}
