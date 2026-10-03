import SwiftUI

@Observable
@MainActor
final class WallpaperAnimationViewModel {
    var renderer: WallpaperShaderRenderer

    init(renderer: WallpaperShaderRenderer) {
        self.renderer = renderer
    }
}

struct WallpaperAnimationView: View {
    let vm: WallpaperAnimationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewport = MetalImageViewport()

    var body: some View {
        MetalImageView(
            viewport: $viewport,
            renderer: vm.renderer,
            reduceMotion: reduceMotion
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
