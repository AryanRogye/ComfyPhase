//
//  VideoWallpaperView.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/3/26.
//

import SwiftUI
import AVKit

@Observable
@MainActor
final class VideoWallpaperViewModel {
    var id = UUID()
    var asset: AVAsset {
        didSet {
            id = UUID()
        }
    }
    init(asset: AVAsset) {
        self.asset = asset
    }
}

struct VideoWallpaperView: View {

    @Bindable var vm: VideoWallpaperViewModel
    @State private var player: AVPlayer?

    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Preparing media...")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: vm.id) {
            if let player {
                player.pause()
            }
            let playerItem = AVPlayerItem(asset: vm.asset)
            self.player = AVPlayer(playerItem: playerItem)
            self.player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
