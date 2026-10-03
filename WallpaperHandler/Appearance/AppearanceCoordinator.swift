//
//  AppearanceCoordinator.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import Foundation
import AppKit
import SwiftUI
import AVKit

final class AppearanceCoordinator {

    /// User Config
    private let defaultsManager: DefaultsManager

    /// this is used so that when observation is triggered we know the last
    /// used appearance and can change to it
    private var lastAppearance: Appearance? = nil

    /// Optional rather than lazy because user may not want this in general
    private var videoWallpaperController: VideoWallpaperController?

    private var wallpaperAnimationController: WallpaperAnimationController?

    init(defaultsManager: DefaultsManager) {
        self.defaultsManager = defaultsManager
        observeDefaults()

        /// DEBUG: We need this delete when done
        videoWallpaperController = .init()
        wallpaperAnimationController = .init()
    }


    public func appearanceDidChange(_ appearance: Appearance) {
        self.lastAppearance = appearance
        guard let lastSelectedWallpaperContainer = defaultsManager.lastSelectedWallpaperContainer else {
            return
        }
        guard let container = defaultsManager.wallpaperContainers.first(where: { $0.id == lastSelectedWallpaperContainer }) else {
            return
        }

        switch appearance {
        case .light:
            changeMacWallpaper(with: container.lightImageUrl, type: .shader)
        case .dark:
            changeMacWallpaper(with: container.darkImageUrl, type: .shader)
        }
    }
}

// MARK: - Observation
extension AppearanceCoordinator {

    /// When a UUID for the selected container changes
    /// we trigger the function that changes the wallpaper
    private func observeDefaults() {
        withObservationTracking {
            _ = defaultsManager.lastSelectedWallpaperContainer;
            _ = defaultsManager.weatherMode
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                if let lastAppearance = self.lastAppearance {
                    self.appearanceDidChange(lastAppearance)
                }
                self.observeDefaults()
            }
        }
    }
}

/// MARK: - Wallpaper Change
extension AppearanceCoordinator {
    private enum ChangeType {
        case legacy
        case shader
        case video
    }

    private func changeMacWallpaper(with imageURL: URL, type: ChangeType) {
        switch type {
        case .legacy:
            legacyChange(with: imageURL)
        case .shader:
            shaderChange(with: imageURL)
        case .video:
            videoChange(with: imageURL)
        }
    }

    internal func legacyChange(with imageURL: URL) {
        let screens = NSScreen.screens

        for screen in screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
            } catch {
                print("Error changing wallpaper: \(error.localizedDescription)")
            }
        }
    }

    internal func shaderChange(with imageURL: URL) {
        if let weatherMode = defaultsManager.weatherMode {
            wallpaperAnimationController?.changeWallpaper(to: imageURL, mode: weatherMode)
        } else {
            legacyChange(with: imageURL)
        }
    }

    internal func videoChange(with imageURL: URL) {
        Task {
            await videoWallpaperController?.changeWallpaper(to: imageURL)
        }
    }
}
