//
//  ApplicationSupport.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import AppKit

enum ApplicationSupport {

    static var directory: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
    }

    static var appDirectory: URL {
        let url = directory.appending(
            path: Bundle.main.bundleIdentifier ?? "WallpaperHandler",
            directoryHint: .isDirectory
        )

        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )

        return url
    }

    public static func storeAndGetUrl(_ image: NSImage) -> URL? {
        return image.toFileURL(at: appDirectory)
    }
}
