//
//  DefaultKeys.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import Foundation

extension UserDefaults.Keys {
    static let wallpaperContainers = UserDefaults.Key<[WallpaperContainer]>("wallpaper_container", default: [])
    static let lastSelectedWallpaperContainer = UserDefaults.Key<UUID?>("last_selected_wallpaper_container", default: nil)
}
