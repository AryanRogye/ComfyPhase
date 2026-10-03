//
//  NSImage+toFileURL.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import AppKit

/// Converts an NSImage to a local file URL by saving it as a PNG
extension NSImage {

    @discardableResult
    func toFileURL(at location: URL) -> URL? {
        // 1. Get the TIFF data representation of the image
        guard let tiffData = self.tiffRepresentation else { return nil }

        // 2. Convert the TIFF representation to a PNG bitmap representation
        guard let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        // 3. Define a temporary file location
        let fileName = "image_\(UUID().uuidString).png"
        let fileURL = location.appendingPathComponent(fileName)

        // 4. Write the image data to disk
        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing image to disk: \(error)")
            return nil
        }
    }
}
