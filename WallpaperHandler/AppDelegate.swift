//
//  AppDelegate.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 9/30/26.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    var appCoordinator: AppCoordinator?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.isSwiftUIPreview else { return }

        appCoordinator = AppCoordinator()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@Observable
@MainActor
final class WallpaperHandlerViewModel {
    var appearance: Appearance = .light
}

@MainActor
class AppCoordinator {

    var appearance: NSKeyValueObservation?
    var menubarCoordinator: MenuBarCoordinator = .init()
    var wallpaperHandlerVM: WallpaperHandlerViewModel = .init()
    var appearanceWatcher: AppearanceWatcher = .init()
    var defaultsManager: DefaultsManager = .init()

    lazy var appearanceCoordinator: AppearanceCoordinator = .init(
        defaultsManager: defaultsManager
    )

    init() {
        appearanceWatcher.assignHandlerAndStart(didAppearanceChange: { [weak self] appearance in
            guard let self else { return }
            self.wallpaperHandlerVM.appearance = appearance
            self.appearanceCoordinator.appearanceDidChange(appearance)
        })

        menubarCoordinator.start(
            wallpaperHandlerVM: wallpaperHandlerVM,
            defaultsManager: defaultsManager
        )
    }
}
