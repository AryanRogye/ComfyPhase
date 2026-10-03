//
//  VideoWallpaperController.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/3/26.
//

import Foundation
import SwiftUI
import AVKit

@MainActor
final class VideoWallpaperController {

    private class ModelContextKey: Hashable, Sendable {
        let id: CGDirectDisplayID
        let frame: NSRect
        let backingScaleFactor: CGFloat

        init(id: CGDirectDisplayID, frame: NSRect, backingScaleFactor: CGFloat) {
            self.id = id
            self.frame = frame
            self.backingScaleFactor = backingScaleFactor
        }

        /// Hashable Conformation
        static func == (
            lhs: borrowing VideoWallpaperController.ModelContextKey,
            rhs: borrowing VideoWallpaperController.ModelContextKey
        ) -> Bool {
            return lhs.id == rhs.id
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private class ModelContext {
        let window: NSWindow
        let vm: VideoWallpaperViewModel

        init(
            window: NSWindow,
            vm: VideoWallpaperViewModel,
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
                backingScaleFactor: screen.backingScaleFactor
            )] = .some(nil)
        }
    }

    public func changeWallpaper(to url: URL) async {
        guard let cgImage = url.convertURLToCGImage() else {
            print("Error Converting URL: \(url.path) To CGImage")
            return
        }

        for (screenKey, value) in windows {
            guard let asset = await Self.getAsset(
                from: cgImage,
                screenWidth: screenKey.frame.width,
                screenHeight: screenKey.frame.height,
                screenBackingScaleFactor: screenKey.backingScaleFactor
            ) else {
                print("Error Creating An AVAsset")
                continue
            }

            if let value {
                value.vm.asset = asset
                continue
            }

            let vm = VideoWallpaperViewModel(asset: asset)

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

            let swiftUIView = VideoWallpaperView(vm: vm)
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

    private static func getAsset(
        from image: CGImage,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        screenBackingScaleFactor: CGFloat
    ) async -> AVAsset? {
        return try? await VideoCreator.makeAsset(
            from: image,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            screenBackingScaleFactor: screenBackingScaleFactor
        )
    }
}
