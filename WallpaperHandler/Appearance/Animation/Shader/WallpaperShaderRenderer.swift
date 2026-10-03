import Foundation
@preconcurrency import Metal
import MetalKit
import QuartzCore
import CoreImage

enum WeatherMode: String, Codable {
    case rain, snow, blossoms, autumn
    var title: String {
        switch self {
        case .blossoms: "Cherry Blossoms"
        case .autumn: "Autumn Leaves"
        default: rawValue.capitalized
        }
    }
    var symbol: String {
        switch self {
        case .rain: "cloud.rain"
        case .snow: "cloud.snow"
        case .blossoms: "camera.macro"
        case .autumn: "leaf"
        }
    }
}

/// Renders a fixed image plus animated weather, without windows or screen capture.
/// All textures use the image's pixel dimensions. `pixelsPerPoint` controls particle
/// size/speed independently of image resolution (use 2 for a Retina-sized image).
@MainActor
final class WallpaperShaderRenderer: NSObject {
    enum RenderError: LocalizedError {
        case metalUnavailable, missingShader(String), allocationFailed
        case invalidScale, invalidTime, incompatibleOutput, wrongDevice, encoderUnavailable
        case tooManyFramesInFlight, gpuFailed(String)

        var errorDescription: String? {
            switch self {
            case .metalUnavailable: "Metal is unavailable."
            case .missingShader(let name): "Missing Metal shader: \(name). Include WallpaperShaders.metal in the app target."
            case .allocationFailed: "Unable to allocate weather rendering resources."
            case .invalidScale: "pixelsPerPoint must be finite and greater than zero."
            case .invalidTime: "Animation time must be finite and nonnegative."
            case .incompatibleOutput: "Output texture must match the background size/format and support renderTarget and shaderRead usage."
            case .wrongDevice: "Textures and command buffers must use the renderer's Metal device."
            case .encoderUnavailable: "Unable to create a Metal encoder."
            case .tooManyFramesInFlight: "Two weather frames are already in flight; skip this frame or await an earlier render."
            case .gpuFailed(let message): "Weather rendering failed: \(message)"
            }
        }
    }

    // These layouts mirror Drop and Uniforms in WallpaperShaders.metal.
    private struct Particle {
        var origin: SIMD4<Float>
        var shape: SIMD4<Float>
        var variation: SIMD4<Float>
    }
    private struct Uniforms {
        var viewport: SIMD2<Float>
        var time: Float
        var motion: Float
    }

    private let context: MetalContext
    var device: MTLDevice { context.device }
    let mode: WeatherMode
    let pixelSize: CGSize
    let pixelFormat: MTLPixelFormat
    private let pipeline: MTLRenderPipelineState
    private let background: MTLTexture
    var backgroundTexture: MTLTexture { background }
    private let drops: MTLBuffer
    private let dropCount: Int
    private let pixelsPerPoint: Float
    private let start = CACurrentMediaTime()
    private var activeRenders = 0

    init(
        image: CGImage,
        mode: WeatherMode,
        context: MetalContext = .shared,
        pixelsPerPoint: Float = 1,
        imageScale: CGFloat = 1
    ) throws {
        guard pixelsPerPoint.isFinite, pixelsPerPoint > 0,
              imageScale.isFinite, imageScale > 0, imageScale <= 1 else { throw RenderError.invalidScale }
        self.context = context
        let device = context.device
        self.mode = mode
        self.pixelsPerPoint = pixelsPerPoint
        // Core Image honors the embedded ICC profile. Extended linear RGB keeps
        // wide-gamut values outside 0...1 instead of clipping them to sRGB.
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: max(1, Int(ceil(CGFloat(image.width) * imageScale))),
            height: max(1, Int(ceil(CGFloat(image.height) * imageScale))),
            mipmapped: false
        )
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw RenderError.allocationFailed
        }
        let imageContext = CIContext(mtlDevice: device, options: [
            .workingColorSpace: colorSpace,
            .cacheIntermediates: false
        ])
        let destination = CIRenderDestination(mtlTexture: texture, commandBuffer: nil)
        destination.colorSpace = colorSpace
        // Match the top-left UV coordinates used by the wallpaper shaders.
        destination.isFlipped = true
        let source = CIImage(cgImage: image).transformed(by: CGAffineTransform(
            scaleX: CGFloat(texture.width) / CGFloat(image.width),
            y: CGFloat(texture.height) / CGFloat(image.height)))
        let upload = try imageContext.startTask(toRender: source, to: destination)
        try upload.waitUntilCompleted()
        imageContext.clearCaches()
        background = texture
        pixelSize = CGSize(width: background.width, height: background.height)
        pixelFormat = background.pixelFormat
        let library = context.library
        let fragmentName: String
        switch mode {
        case .rain: fragmentName = "rainFragment"
        case .snow: fragmentName = "snowFragment"
        case .blossoms: fragmentName = "blossomFragment"
        case .autumn: fragmentName = "autumnFragment"
        }
        guard let vertex = library.makeFunction(name: "rainVertex"),
              let fragment = library.makeFunction(name: fragmentName) else {
            throw RenderError.missingShader(fragmentName)
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        let color = descriptor.colorAttachments[0]!
        color.pixelFormat = background.pixelFormat
        color.isBlendingEnabled = true
        color.sourceRGBBlendFactor = .one
        color.destinationRGBBlendFactor = .oneMinusSourceAlpha
        color.sourceAlphaBlendFactor = .one
        color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        dropCount = mode == .autumn ? 120 : (mode == .blossoms ? 180 : 479)
        var particles = (0..<dropCount).map { _ in
            let bead = Float.random(in: 0...1) < 0.65
            let radius = Float.random(in: bead ? 4...11 : 4...8)
            return Particle(origin: SIMD4(Float.random(in: 0...1), Float.random(in: 0...1), bead ? Float.random(in: 2...14) : Float.random(in: 65...170), Float.random(in: 0...10)),
                shape: SIMD4(radius, bead ? radius * Float.random(in: 1...1.6) : Float.random(in: 20...65), Float.random(in: 0.88...0.98), Float.random(in: 0.6...1)),
                variation: SIMD4(Float.random(in: 0...100), Float.random(in: -3...3), Float.random(in: 14...30), 0))
        }
        if mode == .snow {
            particles = (0..<dropCount).map { _ in
                let depth = Float.random(in: 0.2...1)
                let radius = 1 + depth * 4
                return Particle(origin: SIMD4(Float.random(in: 0...1), Float.random(in: 0...1), 15 + depth * 65, Float.random(in: 0...10)),
                    shape: SIMD4(radius, radius, 0.3 + depth * 0.65, depth),
                    variation: SIMD4(Float.random(in: 0...100), 8 + depth * 28, 0, 1))
            }
        }
        if mode == .blossoms {
            particles = (0..<dropCount).map { _ in
                let depth = Float.random(in: 0.25...1)
                let radius = 3 + depth * 6
                return Particle(origin: SIMD4(Float.random(in: 0...1), Float.random(in: 0...1), 14 + depth * 38, Float.random(in: 0...10)),
                    shape: SIMD4(radius, radius * 1.25, 0.55 + depth * 0.4, depth),
                    variation: SIMD4(Float.random(in: 0...100), 20 + depth * 45, Float.random(in: 0.5...1.3), 2))
            }
        }
        if mode == .autumn {
            particles = (0..<dropCount).map { _ in
                let depth = Float.random(in: 0.25...1)
                let radius = 6 + depth * 10
                return Particle(origin: SIMD4(Float.random(in: 0...1), Float.random(in: 0...1), 18 + depth * 36, Float.random(in: 0...10)),
                    shape: SIMD4(radius * 0.75, radius * 1.55, 0.65 + depth * 0.3, depth),
                    variation: SIMD4(Float.random(in: 0...100), 35 + depth * 60, Float.random(in: 0.35...0.85), 3))
            }
        }
        guard let buffer = device.makeBuffer(bytes: particles,
                length: MemoryLayout<Particle>.stride * particles.count, options: .storageModeShared) else {
            throw RenderError.allocationFailed
        }
        drops = buffer
        super.init()
    }

    /// Allocate an independently owned output; reusable with encode(into:...).
    func makeOutputTexture() throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
            width: background.width, height: background.height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw RenderError.allocationFailed }
        texture.label = "Wallpaper \(mode.rawValue) output"
        return texture
    }

    /// Draw weather over an already drawn background, directly into a display drawable.
    func encodeParticles(into encoder: MTLRenderCommandEncoder, size: CGSize,
                         scale: Float = 1, at time: TimeInterval? = nil,
                         reduceMotion: Bool = false) {
        var uniforms = Uniforms(
            viewport: SIMD2(Float(size.width), Float(size.height)) / scale,
            time: Float(time ?? (CACurrentMediaTime() - start)),
            motion: reduceMotion ? 0 : 1)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(drops, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentTexture(background, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: dropCount)
    }

    /// Append GPU work to the caller's uncommitted command buffer. No waits or commit.
    /// The caller owns synchronization and must not reuse an output still being consumed.
    /// The background and output are separate: rain never samples its own render target.
    func encode(into output: MTLTexture, commandBuffer: MTLCommandBuffer,
                at time: TimeInterval? = nil, reduceMotion: Bool = false) throws {
        let elapsed = time ?? (CACurrentMediaTime() - start)
        guard elapsed.isFinite, elapsed >= 0, elapsed <= Double(Float.greatestFiniteMagnitude) else {
            throw RenderError.invalidTime
        }
        guard output.device.registryID == device.registryID,
              commandBuffer.device.registryID == device.registryID else { throw RenderError.wrongDevice }
        guard output.textureType == .type2D, output.sampleCount == 1,
              output.width == background.width, output.height == background.height,
              output.pixelFormat == pixelFormat, output.usage.contains(.renderTarget),
              output.usage.contains(.shaderRead) else { throw RenderError.incompatibleOutput }
        guard let blit = commandBuffer.makeBlitCommandEncoder() else { throw RenderError.encoderUnavailable }
        blit.copy(from: background, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: background.width, height: background.height, depth: 1),
            to: output, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .load
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { throw RenderError.encoderUnavailable }
        var uniforms = Uniforms(viewport: SIMD2(Float(background.width), Float(background.height)) / pixelsPerPoint,
            time: Float(elapsed), motion: reduceMotion ? 0 : 1)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(drops, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentTexture(background, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: dropCount)
        encoder.endEncoding()
        // Keep source resources alive even if the renderer is released before commit.
        let retainedBackground = background
        let retainedParticles = drops
        commandBuffer.addCompletedHandler { _ in
            _ = retainedBackground
            _ = retainedParticles
        }
    }

    /// Returns a fresh texture after GPU completion, safe to consume on another queue.
    /// Await this from your frame loop; use encode(into:...) for pooled output textures.
    func render(at time: TimeInterval? = nil, reduceMotion: Bool = false) async throws -> MTLTexture {
        guard activeRenders < 2 else { throw RenderError.tooManyFramesInFlight }
        activeRenders += 1
        defer { activeRenders -= 1 }
        let output = try makeOutputTexture()
        guard let command = context.queue.makeCommandBuffer() else { throw RenderError.allocationFailed }
        try encode(into: output, commandBuffer: command, at: time, reduceMotion: reduceMotion)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            command.addCompletedHandler { buffer in
                if buffer.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: RenderError.gpuFailed(buffer.error?.localizedDescription ?? "Unknown GPU error"))
                }
            }
            command.commit()
        }
        return output
    }
}
