//
//  ConfigurationCreator.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/2/26.
//

import UniformTypeIdentifiers
import SwiftUI

struct ConfigurationCreator: View {

    @Bindable var vm: MenubarViewModel
    @Binding var error: String?
    @Binding var showError: Bool
    var onClose: () -> Void
    var onSave: (String, NSImage, NSImage) -> Void

    var shouldShowSave: Bool {
        vm.draftLightImage != nil && vm.draftDarkImage != nil
    }

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Text("Drop Or Select Wallpaper")
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    clearStoredDraftImages()
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .frame(height: 15)
                }

                if shouldShowSave {
                    Button(action: {
                        guard let light = vm.draftLightImage, let dark = vm.draftDarkImage else { return }
                        let name = vm.draftName
                        clearStoredDraftImages()
                        onSave(name, light, dark)
                    }) {
                        Label("Save", systemImage: "checkmark")
                            .frame(height: 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring, value: shouldShowSave)

            TextField("Wallpaper Name", text: $vm.draftName)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 4)

            HStack {
                DropArea(
                    label: "Light Mode Wallpaper",
                    image: $vm.draftLightImage,
                    error: $error,
                    showError: $showError
                )
                DropArea(
                    label: "Dark Mode Wallpaper",
                    image: $vm.draftDarkImage,
                    error: $error,
                    showError: $showError
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func clearStoredDraftImages() {
        vm.draftName = ""
        vm.draftLightImage = nil
        vm.draftDarkImage = nil
    }
}

private struct DropArea: View {

    @State private var isDropping: Bool = false
    @State private var isFileImporterPresented: Bool = false

    let label: String
    @Binding var image: NSImage?
    @Binding var error: String?
    @Binding var showError: Bool

    var body: some View {
        Button(action: {
            isFileImporterPresented = true
        }) {
            ZStack {
                Group {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                minWidth: 0,
                                maxWidth: .infinity,
                                minHeight: 0,
                                maxHeight: .infinity
                            )
                            .clipped()
                            .clipShape(.rect(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDropping ? Color.accentColor.opacity(0.2) : .secondary.opacity(0.2))
                    }
                }
                .dropDestination(for: URL.self) { items, _ in
                    handleDrop(items: items)
                } isTargeted: { inside in
                    withAnimation(.bouncy) {
                        isDropping = inside
                    }
                }
                if isDropping {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.accentColor,
                            style: .init(lineWidth: 1, dash: [5])
                        )
                }

                Text(label)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                handleImportingFile(url: url)
            case .failure(let failure):
                self.error = failure.localizedDescription
                self.showError = true
            }
        }
    }

    private func handleDrop(items: [URL]) -> Bool {
        guard items.count == 1 else {
            error = "Cant Drop Multiple Images Just One"
            showError = true
            return false
        }

        guard let image = NSImage(contentsOf: items[0]) else {
            error = "Couldn't load image"
            showError = true
            return false
        }

        self.image = image
        return true
    }

    private func handleImportingFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            error = "Couldn't access image"
            showError = true
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        guard let image = NSImage(contentsOf: url) else {
            error = "Couldn't load image"
            showError = true
            return
        }

        self.image = image
    }
}
