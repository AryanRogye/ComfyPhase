//
//  MetalContext.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/3/26.
//

import MetalKit

/// Shared device, command queue, and compiled shaders for the app.
@MainActor
public final class MetalContext {

    public static let shared = MetalContext()
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let library: MTLLibrary

    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is unavailable on this system.")
        }
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create a Metal command queue.")
        }

        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load default.metallib. Ensure the app's Metal shaders belong to its target.")
        }

        queue.label = "WallpaperHandler shared Metal queue"
        self.device = device
        self.queue = queue
        self.library = library
    }
}
