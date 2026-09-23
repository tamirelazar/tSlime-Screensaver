// Disposable single-choice Settings model adapted from Aerial 2fcb2b8.

import AppKit
import Foundation

private let probeChoiceID = "geometry"
private let probeDisplayName = "Native Wallpaper Geometry Probe"

func buildSettingsViewModelsXPC() async -> AnyObject? {
    let bundleID = Bundle.main.bundleIdentifier ?? "local.oozel.native-wallpaper-probe.host.extension"
    let groupID = GroupID(id: "geometry-group")

    guard let thumbnailURL = probeThumbnailURL() else {
        debugLog("  [Settings] Failed to generate thumbnail")
        return makeEmptyGroupsResponse()
    }

    let choiceID = ChoiceID(
        id: probeChoiceID,
        descriptor: ChoiceIDDescriptor(
            provider: ChoiceProviderID(rawValue: bundleID),
            identifier: probeChoiceID,
            files: [],
            configuration: Data(probeChoiceID.utf8),
        ),
    )

    let choiceDescriptor = ChoiceDescriptor(
        id: choiceID,
        provider: ChoiceProviderID(rawValue: bundleID),
        identifier: probeChoiceID,
        name: probeDisplayName,
        localizedDescription: "Disposable geometry calibration",
        thumbnail: .image(url: thumbnailURL),
        isDownloaded: true,
        options: [],
    )

    let item = SettingsItem(
        id: choiceID,
        localizedName: probeDisplayName,
        thumbnail: .image(url: thumbnailURL),
        choice: choiceDescriptor,
        contentBadge: .none,
        showInTopLevel: true,
        sortOrder: 0,
        disposability: .none,
    )

    let group = SettingsGroup(
        id: groupID,
        items: [item],
        localizedName: "Geometry Probe",
        disposability: .none,
        sortOrder: -50,
        sortID: GroupSortID(id: "local.oozel.native-wallpaper-probe"),
        allChoiceID: nil,
        shouldHideItemLabels: false,
        contextMenu: nil,
        thumbnail: nil,
    )

    let viewModel = SettingsViewModel(
        groups: [group],
        refreshPolicy: .default,
        isModificationDisabled: false,
    )

    // The Screen Saver picker discovers the non-nil screenSaver model.
    let viewModels = SettingsViewModels(
        desktop: viewModel,
        screenSaver: viewModel,
    )

    return remapToRealXPC(viewModels)
}

/// Fallback: empty groups view model.
func makeEmptyGroupsResponse() -> AnyObject? {
    let emptyViewModel = SettingsViewModel(
        groups: [],
        refreshPolicy: .default,
        isModificationDisabled: false,
    )
    let empty = SettingsViewModels(
        desktop: emptyViewModel,
        screenSaver: emptyViewModel,
    )
    return remapToRealXPC(empty)
}

/// Archive via ShimViewModelsXPC, remap class name on unarchive to WallpaperSettingsViewModelsXPC.
private func remapToRealXPC(_ viewModels: SettingsViewModels) -> AnyObject? {
    let shim = ShimViewModelsXPC(value: viewModels)

    let data: Data
    do {
        data = try NSKeyedArchiver.archivedData(withRootObject: shim, requiringSecureCoding: false)
    } catch {
        debugLog("  [Remap] Archive failed: \(error)")
        return nil
    }

    guard let realClass = objc_getClass("WallpaperSettingsViewModelsXPC") as? AnyClass else {
        debugLog("  [Remap] WallpaperSettingsViewModelsXPC class not found")
        return nil
    }

    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
        debugLog("  [Remap] Failed to create unarchiver")
        return nil
    }
    unarchiver.requiresSecureCoding = false
    unarchiver.decodingFailurePolicy = .setErrorAndReturn
    unarchiver.setClass(realClass, forClassName: "ShimViewModelsXPC")

    let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
    if let error = unarchiver.error {
        debugLog("  [Remap] Unarchive error: \(error)")
    }
    unarchiver.finishDecoding()

    return result as AnyObject?
}

/// Stage the bundled calibration thumbnail into the Caches directory.
/// (System Settings reads this URL; staging to our Caches dir matches the location the
/// previous generated thumbnail used and is known to be readable by WallpaperAgent.)
private func probeThumbnailURL() -> URL? {
    let fm = FileManager.default
    guard let src = Bundle.main.url(forResource: "reference", withExtension: "png") else {
        debugLog("  [Settings] Bundled thumbnail not found")
        return nil
    }
    guard let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        return src
    }
    try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    let dst = cacheDir.appendingPathComponent("native-wallpaper-probe-thumbnail.png")
    do {
        try Data(contentsOf: src).write(to: dst, options: .atomic)
        return dst
    } catch {
        debugLog("  [Settings] Failed to stage thumbnail: \(error)")
        return src
    }
}
