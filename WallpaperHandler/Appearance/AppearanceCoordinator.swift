//
//  AppearanceCoordinator.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import Foundation
import AppKit

final class AppearanceCoordinator {

    let defaultsManager: DefaultsManager
    private var lastAppearance: Appearance? = nil

    init(defaultsManager: DefaultsManager) {
        self.defaultsManager = defaultsManager
        observeLastSelectedWallpaperContainer()
    }


    private func observeLastSelectedWallpaperContainer() {
        withObservationTracking {
            _ = defaultsManager.lastSelectedWallpaperContainer
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                if let lastAppearance = self.lastAppearance {
                    self.appearanceDidChange(lastAppearance)
                }
                self.observeLastSelectedWallpaperContainer()
            }
        }

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
            changeMacWallpaper(with: container.lightImageUrl)
        case .dark:
            changeMacWallpaper(with: container.darkImageUrl)
        }
    }

    func changeMacWallpaper(with imageURL: URL) {
        // Get all connected screens (displays)
        let screens = NSScreen.screens

        // Loop through each screen and update the background
        for screen in screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
            } catch {
                print("Error changing wallpaper: \(error.localizedDescription)")
            }
        }
    }
}
