//
//  AppearanceWatcher.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 9/30/26.
//

import AppKit

enum Appearance: String {
    case light = "Light Mode"
    case dark = "Dark Mode"
}

private extension NSApplication {
    var appearance: Appearance {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }
}

final class AppearanceWatcher {

    private var appearanceObserver: NSKeyValueObservation?
    private var didAppearanceChange: ((Appearance) -> Void)?

    init() {}

    public func beginObservingAppearance() {

        guard appearanceObserver == nil else {
            print("Attempted to start observing appearance but observer is already set")
            return
        }

        didAppearanceChange?(NSApp.appearance)

        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] app, change in
            guard let self else { return }
            didAppearanceChange?(app.appearance)
        }
    }

    public func stopObservingAppearance() {
        appearanceObserver?.invalidate()
    }

    public func assignHandler(
        didAppearanceChange: @escaping (Appearance) -> Void
    ) {
        self.didAppearanceChange = didAppearanceChange
    }

    public func assignHandlerAndStart(
        didAppearanceChange: @escaping (Appearance) -> Void
    ) {
        self.didAppearanceChange = didAppearanceChange
        beginObservingAppearance()
    }
}
