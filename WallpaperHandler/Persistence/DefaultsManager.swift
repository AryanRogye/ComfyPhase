//
//  DefaultsManager.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import Foundation

@Observable
@MainActor
final class DefaultsManager {
    var lastSelectedWallpaperContainer: UUID? = UserDefaults.standard[.lastSelectedWallpaperContainer] {
        didSet {
            UserDefaults.standard[.lastSelectedWallpaperContainer] = lastSelectedWallpaperContainer
        }
    }
    var wallpaperContainers: [WallpaperContainer] = UserDefaults.standard[.wallpaperContainers] {
        didSet {
            UserDefaults.standard[.wallpaperContainers] = wallpaperContainers
        }
    }
    var weatherMode: WeatherMode? = UserDefaults.standard[.weatherMode] {
        didSet {
            UserDefaults.standard[.weatherMode] = weatherMode
        }
    }
}
