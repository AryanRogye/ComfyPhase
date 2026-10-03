//
//  MenubarMenu.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import SwiftUI

struct MenubarMenu<Label: View, Content: View>: View {

    @ViewBuilder var content: Content
    @ViewBuilder var label: Label

    @State private var menubarPanel: MenubarMenuPanel<Content>?
    @State private var frame: NSRect?
    @State private var window: NSWindow?

    var body: some View {
        MenubarHoverStyle {
            label
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 12)
        } onHover: { hovering in
            guard let frame else { return }
            guard let window else { return }
            if hovering {
                let anchor = Self.screenRect(of: frame, in: window)
                menubarPanel?.showPanel(anchor: anchor)
            } else {
                menubarPanel?.hidePanel()
            }
        }
        .background(WindowReader { window = $0 })
        .task {
            menubarPanel = .init(
                content: content
            )
        }
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { newValue in
            self.frame = newValue
        }

    }

    // SwiftUI global (top-left, window space) -> AppKit screen space (bottom-left)
    private static func screenRect(of f: CGRect, in window: NSWindow) -> NSRect {
        let contentHeight = window.contentView?.bounds.height ?? window.frame.height
        let inWindow = NSRect(
            x: f.minX,
            y: contentHeight - f.maxY,
            width: f.width,
            height: f.height
        )
        return window.convertToScreen(inWindow)
    }
}

private struct WindowReader: NSViewRepresentable {
    var onChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowView()
        view.onChange = onChange
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class WindowView: NSView {
        var onChange: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.onChange?(self?.window)
            }
        }
    }
}

private struct MenuBarMenuWrapper<Content: View>: View {

    @ViewBuilder var content: Content
    @State private var isHovering: Bool = false

    var body: some View {
        VStack {
            content
                .fixedSize()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .containerShape(.rect(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .onHover {
            isHovering = $0
        }
    }
}

private final class MenubarMenuPanel<Content: View>: NSObject {

    typealias Wrapper = MenuBarMenuWrapper
    let content: Content

    var panel: NSPanel?
    private var hostingController: NSHostingController<Wrapper<Content>>?

    init(content: Content) {
        self.content = content
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let contentView = MenuBarMenuWrapper { content }

        let hostingController = NSHostingController(
            rootView: contentView
        )
        hostingController.sizingOptions = [
            .intrinsicContentSize
        ]
        let panel = FocusablePanel(
            contentRect: .zero,
            styleMask: [
                .nonactivatingPanel,
                .borderless
            ], backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .popUpMenu

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentViewController = hostingController
        self.hostingController = hostingController
        self.panel = panel
    }

    public func showPanel(anchor: NSRect) {
        guard let panel else { return }

        hostingController?.view.layoutSubtreeIfNeeded()
        if let size = hostingController?.view.fittingSize,
           size.width > 0, size.height > 0 {
            panel.setContentSize(size)
        }

        let size = panel.frame.size
        let gap: CGFloat = 0   // see note below

        // Use the screen the row is actually on, not the one under the mouse
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) }
        ?? Self.screenUnderMouse()
        let visible = screen?.visibleFrame ?? .infinite

        // Prefer right, fall back to left
        var x = anchor.maxX + gap
        if x + size.width > visible.maxX {
            x = anchor.minX - size.width - gap
        }
        x = max(x, visible.minX)   // if neither side fits, at least stay on screen

        // Align panel's top with the row's top, then clamp vertically
        var y = anchor.maxY - size.height
        y = min(max(y, visible.minY), visible.maxY - size.height)

        panel.setFrameOrigin(NSPoint(x: x, y: y))

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    public func hidePanel() {
        panel?.orderOut(nil)
    }

    /**
     * Grab the screen under the mouse
     */
    public nonisolated static func screenUnderMouse() -> NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(loc, $0.frame, false)
        }
    }
}
