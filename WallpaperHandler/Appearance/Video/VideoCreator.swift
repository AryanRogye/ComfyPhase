//
//  VideoCreator.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/3/26.
//

import AVKit

nonisolated enum VideoCreator {

    private static let ciContext = CIContext(options: nil)

    public static func makeAsset(
        from image: CGImage,
        duration: Double = 5,
        fps: Int32 = 30,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        screenBackingScaleFactor: CGFloat
    ) async throws -> AVURLAsset {
        try await Task.detached(priority: .userInitiated) {
            let url = FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            let w = Int(screenWidth * screenBackingScaleFactor) & ~1
            let h = Int(screenHeight * screenBackingScaleFactor) & ~1

            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: w,
                AVVideoHeightKey: h
            ])

            let pixelBufferReceiver = writer.inputPixelBufferReceiver(
                for: input,
                pixelBufferAttributes: createPixelBufferAttributes(w: w, h: h)
            )

            try writer.start()
            writer.startSession(atSourceTime: .zero)


            /// we convert the duration into a end time
            let end = duration.toCMTime(with: fps)
            let totalFrames = Int(duration * Double(fps))

            // 2. Generate timestamps for EVERY frame, not just the start and end
            var timestamps: [CMTime] = []
            for frame in 0...totalFrames {
                let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))
                timestamps.append(time)
            }

            for t in timestamps {
                let updatedImage = await getUpdatedImage(for: t, end: end, image: image)
                let buffer = try createImageBuffer(w: w, h: h, image: updatedImage)
                let readOnlyPixelBuffer = CVReadOnlyPixelBuffer(unsafeBuffer: buffer)
                try await pixelBufferReceiver.append(readOnlyPixelBuffer, with: t)
            }


            input.markAsFinished()
            writer.endSession(atSourceTime: end)
            await writer.finishWriting()
            if writer.status == .failed { throw writer.error ?? NSError(domain: "writer", code: 2) }

            return AVURLAsset(url: url)
        }.value
    }

    /// creates a receiver configured to accept pixel buffers with sepcific attributes
    private static func createPixelBufferAttributes(w: Int, h: Int) -> CVPixelBufferCreationAttributes? {
        let rawAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let partialAttributes = CVPixelBufferAttributes(rawAttributes: rawAttributes)
        return CVPixelBufferCreationAttributes(partialAttributes)
    }

    private static func createImageBuffer(w: Int, h: Int, image: CGImage) throws -> CVPixelBuffer {
        // 1. Calculate the aspect fill dimensions
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        let widthRatio = CGFloat(w) / imageWidth
        let heightRatio = CGFloat(h) / imageHeight

        // Use the larger ratio to ensure the image completely fills the target size (clipping the excess)
        let scale = max(widthRatio, heightRatio)

        let drawWidth = imageWidth * scale
        let drawHeight = imageHeight * scale

        // Center the image so the edges are cut off evenly from both sides
        let drawX = (CGFloat(w) - drawWidth) / 2.0
        let drawY = (CGFloat(h) - drawHeight) / 2.0
        let drawRect = CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)

        // 2. Draw the image into the pixel buffer
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &buffer)

        guard let buffer else { throw NSError(domain: "pb", code: 1) }

        CVPixelBufferLockBaseAddress(buffer, [])
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        ctx?.interpolationQuality = .high
        // The context will automatically clip anything drawn outside of its (0, 0, w, h) bounds
        ctx?.draw(image, in: drawRect)
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
}

extension VideoCreator {
    /// Function Gets the Image for the current time
    private static func getUpdatedImage(for currentTime: CMTime, end: CMTime, image: CGImage) async -> CGImage {
        await Task.detached(priority: .userInitiated) {

            let currentSeconds = CMTimeGetSeconds(currentTime)
            let endSeconds = CMTimeGetSeconds(end)

            /// Progress between 0 and 1
            let progress = endSeconds > 0 ? max(0.0, min(1.0, currentSeconds / endSeconds)) : 0.0

            // Quick escape bounds
            if progress <= 0 { return image }
            return image

            let nsImage = NSImage(named: "BB")!
            guard let targetCGImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                fatalError("Cant Convert NSImage to CGImage")
            }

            // 1. Setup CIImages
            let startCIImage = CIImage(cgImage: image)
            let extent = startCIImage.extent

            var endCIImage = CIImage(cgImage: targetCGImage)

            // 2. SCALE & FILL: Adjust the second image to perfectly match the first image's aspect ratio
            let scaleX = extent.width / endCIImage.extent.width
            let scaleY = extent.height / endCIImage.extent.height

            // Use the maximum scale to fill the frame ( Aspect Fill )
            // (Change to min(scaleX, scaleY) if you prefer Aspect Fit with letterboxing)
            let fillScale = max(scaleX, scaleY)

            // Apply scale and center crop the second image
            endCIImage = endCIImage.transformed(by: CGAffineTransform(scaleX: fillScale, y: fillScale))

            // Center the scaled image over the target bounds
            let cropX = (endCIImage.extent.width - extent.width) / 2
            let cropY = (endCIImage.extent.height - extent.height) / 2
            endCIImage = endCIImage.cropped(to: CGRect(x: extent.origin.x + cropX, y: extent.origin.y + cropY, width: extent.width, height: extent.height))
            // Reset origin so it aligns perfectly with the start image bounds
            endCIImage = endCIImage.transformed(by: CGAffineTransform(translationX: -endCIImage.extent.origin.x, y: -endCIImage.extent.origin.y))

            if progress >= 1 {
                return await ciContext.createCGImage(endCIImage, from: extent) ?? targetCGImage
            }

            // 3. Calculate dynamic blur radius
            let maxBlurRadius: CGFloat = 15.0
            let blurRadius = maxBlurRadius * (1.0 - abs(1.0 - (progress * 2.0)))

            // 4. Apply blur to both images
            var blurredStart = startCIImage
            var blurredEnd = endCIImage

            if blurRadius > 0.5 {
                let clampedStart = startCIImage.clampedToExtent()
                let clampedEnd = endCIImage.clampedToExtent()

                let blurFilter = CIFilter(name: "CIGaussianBlur")!
                blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

                blurFilter.setValue(clampedStart, forKey: kCIInputImageKey)
                blurredStart = blurFilter.outputImage!.cropped(to: extent)

                blurFilter.setValue(clampedEnd, forKey: kCIInputImageKey)
                blurredEnd = blurFilter.outputImage!.cropped(to: extent)
            }

            // 5. Mix the two blurred images using cross-dissolve mask
            let maskColor = CIColor(red: 0, green: 0, blue: 0, alpha: CGFloat(progress))
            let maskImage = CIImage(color: maskColor).cropped(to: extent)

            let blendFilter = CIFilter(name: "CIBlendWithAlphaMask")!
            blendFilter.setValue(blurredEnd, forKey: kCIInputImageKey)
            blendFilter.setValue(blurredStart, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

            // 6. Render back to CGImage
            if let outputCIImage = blendFilter.outputImage,
               let finalCGImage = ciContext.createCGImage(outputCIImage, from: extent) {
                return finalCGImage
            }
            return image
        }.value
    }
}

private extension Double {
    nonisolated func toCMTime(with preferredTimescale: Int32) -> CMTime {
        return CMTime(seconds: self, preferredTimescale: preferredTimescale)
    }
}
