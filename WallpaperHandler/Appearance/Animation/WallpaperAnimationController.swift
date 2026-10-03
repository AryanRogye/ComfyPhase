//
//  WallpaperAnimationController.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/3/26.
//

import Foundation
import SwiftUI

@MainActor
final class WallpaperAnimationController {

    private class ModelContextKey: Hashable, Sendable {
        let id: CGDirectDisplayID
        let frame: NSRect
        init(id: CGDirectDisplayID, frame: NSRect) {
            self.id = id
            self.frame = frame
        }

        /// Hashable Conformation
        static func == (
            lhs: borrowing WallpaperAnimationController.ModelContextKey,
            rhs: borrowing WallpaperAnimationController.ModelContextKey
        ) -> Bool {
            return lhs.id == rhs.id
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private class ModelContext {
        let window: NSWindow
        let vm: WallpaperAnimationViewModel

        init(
            window: NSWindow,
            vm: WallpaperAnimationViewModel,
        ) {
            self.window = window
            self.vm = vm
        }
    }

    /// NSScreenID -> NSWindow
    private var windows: [ModelContextKey: ModelContext?] = [:]

    init() {
        for screen in NSScreen.screens {
            guard let id = screen.displayID else {
                fatalError("NSScreen is missing its CGDirectDisplayID")
            }

            windows[.init(
                id: id,
                frame: screen.frame,
            )] = .some(nil)
        }
    }

    public func changeWallpaper(to url: URL, mode: WeatherMode) {
        guard let cgImage = url.convertURLToCGImage() else {
            print("Error Converting URL: \(url.path) To CGImage")
            return
        }

        // Upload once at the resolution needed for aspect-fill on the largest display.
        let imageScale = min(1, NSScreen.screens.map { screen in
            max(screen.frame.width * screen.backingScaleFactor / CGFloat(cgImage.width),
                screen.frame.height * screen.backingScaleFactor / CGFloat(cgImage.height))
        }.max() ?? 1)
        guard let renderer = try? WallpaperShaderRenderer(
            image: cgImage,
            mode: mode,
            imageScale: imageScale
        ) else { return }

        for (screenKey, value) in windows {
            if let value {
                value.vm.renderer = renderer
                continue
            }

            let vm = WallpaperAnimationViewModel(renderer: renderer)

            let window = NSWindow(
                contentRect: screenKey.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .stationary,
                .ignoresCycle
            ]

            window.isOpaque = true
            window.hasShadow = true
            window.level = NSWindow.Level(
                rawValue: Int(CGWindowLevelForKey(.desktopWindow))
            )

            let swiftUIView = WallpaperAnimationView(vm: vm)
            let hostingView = NSHostingView(rootView: swiftUIView)
            hostingView.frame = window.contentView?.bounds ?? .zero
            hostingView.autoresizingMask = [
                NSView.AutoresizingMask.width,
                NSView.AutoresizingMask.height
            ]
            window.contentView = hostingView

            windows[screenKey] = .init(window: window, vm: vm)
            windows[screenKey]??.window.makeKeyAndOrderFront(nil)
        }
    }
}
