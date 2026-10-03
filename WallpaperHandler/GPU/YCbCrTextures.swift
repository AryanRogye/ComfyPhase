//
//  YCbCrTextures.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/3/26.
//

import MetalKit

public struct YCbCrTextures {
    public let yTexture: MTLTexture
    public let cbCrTexture: MTLTexture
    public let isFullRange: Bool
    private let yCVTexture: CVMetalTexture?
    private let cbCrCVTexture: CVMetalTexture?

    public init(
        yTexture: MTLTexture,
        cbCrTexture: MTLTexture,
        isFullRange: Bool = true
    ) {
        self.yTexture = yTexture
        self.cbCrTexture = cbCrTexture
        self.isFullRange = isFullRange
        self.yCVTexture = nil
        self.cbCrCVTexture = nil
    }

    fileprivate init(
        yTexture: MTLTexture,
        cbCrTexture: MTLTexture,
        isFullRange: Bool,
        yCVTexture: CVMetalTexture,
        cbCrCVTexture: CVMetalTexture
    ) {
        self.yTexture = yTexture
        self.cbCrTexture = cbCrTexture
        self.isFullRange = isFullRange
        self.yCVTexture = yCVTexture
        self.cbCrCVTexture = cbCrCVTexture
    }
}
