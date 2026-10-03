//
//  MenuBarRootView.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 9/30/26.
//

import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class MenubarViewModel {
    var isShowing: Bool = true

    var draftName: String = ""
    var draftLightImage: NSImage?
    var draftDarkImage: NSImage?
}

struct MenuBarRootView: View {

    @Bindable var menubarVM: MenubarViewModel
    @Bindable var wallpaperHandlerVM: WallpaperHandlerViewModel
    @Bindable var defaultsManager: DefaultsManager

    @State private var currentAppearanceImporting: Appearance?
    @State private var isImageUrlPickerPresented: Bool = false

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var isCreatingConfiguration: Bool = false

    var body: some View {
        if menubarVM.isShowing {
            VStack(alignment: .leading) {
                if isCreatingConfiguration {
                    configCreatorView
                } else {
                    header

                    if defaultsManager.wallpaperContainers.isEmpty {
                        emptyConfigView
                    } else {
                        configView
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(width: 300, height: 200, alignment: .topLeading)
            .containerShape(.rect(cornerRadius: 12))
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text("\(error, default: "Unknown Error")")
                )
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Wallpaper Configurations")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isCreatingConfiguration = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Create a wallpaper configuration")
            .accessibilityLabel("Create a wallpaper configuration")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Empty Config View
    private var emptyConfigView: some View {
        HStack {
            Spacer()
            VStack {
                Text("You Have No Configurations")
                    .font(.headline)
                Button(action: {
                    isCreatingConfiguration = true
                }) {
                    Text("Create One")
                }
            }
            Spacer()
        }
        .padding(.top)
    }

    // MARK: - Config View
    private var configView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(defaultsManager.wallpaperContainers) { container in
                    WallpaperConfigurationRow(
                        name: container.name,
                        lightImageURL: container.lightImageUrl,
                        darkImageURL: container.darkImageUrl,
                        isSelected: defaultsManager.lastSelectedWallpaperContainer == container.id,
                        onSelect: {
                            defaultsManager.lastSelectedWallpaperContainer = container.id
                        }
                    )
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            defaultsManager.wallpaperContainers.removeAll { $0.id == container.id }
                            if defaultsManager.lastSelectedWallpaperContainer == container.id {
                                defaultsManager.lastSelectedWallpaperContainer = nil
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Config Creator View
    private var configCreatorView: some View {
        ConfigurationCreator(
            vm: menubarVM,
            error: $error,
            showError: $showError,
            onClose: { isCreatingConfiguration = false },
            onSave: { name, lightImage, darkImage in
                isCreatingConfiguration = false

                guard let lightImageUrl = ApplicationSupport.storeAndGetUrl(lightImage) else {
                    self.error = "Cant Store Light Image"
                    self.showError = true
                    return
                }
                guard let darkImageUrl = ApplicationSupport.storeAndGetUrl(darkImage) else {
                    self.error = "Cant Store Light Image"
                    self.showError = true
                    return
                }

                defaultsManager.wallpaperContainers.append(
                    WallpaperContainer(name: name, lightImageUrl: lightImageUrl, darkImageUrl: darkImageUrl)
                )
            }
        )
    }
}

private struct WallpaperConfigurationRow: View {
    let name: String
    let lightImageURL: URL
    let darkImageURL: URL
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    WallpaperConfigurationPreview(url: lightImageURL, symbol: "sun.max.fill", label: "Light wallpaper")
                    WallpaperConfigurationPreview(url: darkImageURL, symbol: "moon.fill", label: "Dark wallpaper")
                }

                Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : name)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: .rect(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct WallpaperConfigurationPreview: View {
    let url: URL
    let symbol: String
    let label: String

    var body: some View {
        ThumbnailView(url: url, size: 52)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.black.opacity(0.55), in: Circle())
                    .padding(3)
            }
            .accessibilityLabel(label)
    }
}


struct ThumbnailView: View {
    let url: URL
    var size: CGFloat = 100
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.12)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 8))
        .task(id: url) {
            image = await Task.detached(priority: .utility) {
                Self.thumbnail(url: url, maxPixel: 200) // 100pt × 2 for retina
            }.value
        }
    }

    nonisolated private static func thumbnail(url: URL, maxPixel: Int) -> NSImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts) else { return nil }
        let opts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width / 2, height: cg.height / 2))
    }
}

#Preview {

    @Previewable @State var vm = MenubarViewModel()

    MenuBarRootView(
        menubarVM: MenubarViewModel(),
        wallpaperHandlerVM: WallpaperHandlerViewModel(),
        defaultsManager: DefaultsManager()
    )
}
