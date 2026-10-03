//
//  URL+convertToCGImage.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/3/26.
//

import Foundation
import ImageIO

extension URL {
    nonisolated func convertURLToCGImage() -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil) else {
            print("Failed to create image source from URL.")
            return nil
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("Failed to create CGImage from image source.")
            return nil
        }

        return cgImage
    }
}
