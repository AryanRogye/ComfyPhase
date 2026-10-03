//
//  WallpaperContainer.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import Foundation

struct WallpaperContainer: Codable, Identifiable {
    let id: UUID
    let name: String
    let lightImageUrl: URL
    let darkImageUrl: URL
    let createdAt: Date

    init(id: UUID = UUID(), name: String, lightImageUrl: URL, darkImageUrl: URL, createdAt: Date = .now) {
        self.id = id
        self.lightImageUrl = lightImageUrl
        self.darkImageUrl = darkImageUrl
        self.name = name
        self.createdAt = createdAt
    }
}
