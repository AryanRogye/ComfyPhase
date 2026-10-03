//
//  MenuBarCoordinator.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 9/30/26.
//

import AppKit
import SwiftUI

@MainActor
final class MenuBarCoordinator: NSObject {

    typealias MenubarView = MenuBarRootView

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var hostingController: NSHostingController<MenubarView>?

    private var wallpaperHandlerVM: WallpaperHandlerViewModel?
    private var defaultsManager: DefaultsManager?
    private var menubarVM = MenubarViewModel()

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    override init() {
        super.init()
    }

    // MARK: - Public

    public func start(
        wallpaperHandlerVM: WallpaperHandlerViewModel,
        defaultsManager: DefaultsManager
    ) {
        self.wallpaperHandlerVM = wallpaperHandlerVM
        self.defaultsManager = defaultsManager
        configureStatusItem()
        configurePanel()
    }

    public func stop() {
        hidePanel()

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }

        panel?.close()
        panel = nil
        hostingController = nil
    }

    // MARK: - Status Item

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        guard let button = statusItem?.button else {
            return
        }

        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            button.image = image
        } else {
            button.image = NSImage(
                systemSymbolName: "square.grid.2x2",
                accessibilityDescription: nil
            )
        }

        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(togglePanel(_:))
    }

    // MARK: - Panel

    private func configurePanel() {
        guard let wallpaperHandlerVM else {
            fatalError("No WallpaperHandlerViewModel was found while starting Menu Bar")
        }
        guard let defaultsManager else {
            fatalError("No DefaultsManager was found while starting Menu Bar")
        }

        let contentView = MenubarView(
            menubarVM: menubarVM,
            wallpaperHandlerVM: wallpaperHandlerVM,
            defaultsManager: defaultsManager
        )

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
            ],
            backing: .buffered,
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

    // MARK: - Toggle

    @objc
    private func togglePanel(_ sender: Any?) {
        guard let panel else {
            return
        }

        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Show

    private func showPanel() {
        guard
            let panel,
            let button = statusItem?.button
                else {
            return
        }

        hostingController?.view.layoutSubtreeIfNeeded()

        if let size = hostingController?.view.fittingSize,
           size.width > 0,
           size.height > 0
        {
            panel.setContentSize(size)
        }

        let buttonRect =
        button.window?.convertToScreen(
            button.convert(button.bounds, to: nil)
        ) ?? .zero

        let panelSize = panel.frame.size

        var panelOrigin = NSPoint(
            x: buttonRect.midX - panelSize.width / 2,
            y: buttonRect.minY - panelSize.height - 4
        )

        if let screen =
            button.window?.screen ??
            NSScreen.screens.first(where: {
                $0.frame.intersects(buttonRect)
            }) ??
            NSScreen.main
        {
            let visible = screen.visibleFrame

            panelOrigin.x = min(
                max(panelOrigin.x, visible.minX),
                visible.maxX - panelSize.width
            )

            panelOrigin.y = max(
                panelOrigin.y,
                visible.minY
            )
        }

        panel.setFrameOrigin(panelOrigin)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        menubarVM.isShowing = true

        addEventMonitors()
    }

    public func hidePanel() {
        panel?.orderOut(nil)

        menubarVM.isShowing = false
        removeEventMonitors()
    }

    // MARK: - Event Monitors

    private func addEventMonitors() {
        globalEventMonitor =
        NSEvent.addGlobalMonitorForEvents(
            matching: [
                .leftMouseDown,
                .rightMouseDown
            ]
        ) { [weak self] _ in

            guard
                let self,
                let panel = self.panel
                    else {
                return
            }


            // Don't close while our app is active.
            // This lets fileImporter / open panels / etc. work.
            guard !NSApp.isActive else {
                return
            }

            let mouseLocation = NSEvent.mouseLocation

            if panel.frame.contains(mouseLocation) {
                return
            }

            if let button = self.statusItem?.button,
               let buttonWindow = button.window
            {
                let buttonRect =
                buttonWindow.convertToScreen(
                    button.convert(
                        button.bounds,
                        to: nil
                    )
                )

                if buttonRect.contains(mouseLocation) {
                    return
                }
            }

            self.hidePanel()
        }

        localEventMonitor =
        NSEvent.addLocalMonitorForEvents(
            matching: [
                .keyDown,
                .leftMouseDown,
                .rightMouseDown
            ]
        ) { [weak self] event in

            guard
                let self,
                let panel = self.panel
                    else {
                return event
            }

            if event.type == .keyDown &&
                event.keyCode == 53
            {
                self.hidePanel()
                return nil
            }

            if event.type == .leftMouseDown ||
                event.type == .rightMouseDown
            {
                if let button = self.statusItem?.button,
                   let buttonWindow = button.window,
                   event.window == buttonWindow
                {
                    return event
                }

                if event.window == panel {
                    return event
                }

                if let clickedWindow = event.window {
                    if clickedWindow.level >= panel.level {
                        return event
                    }

                    if panel.childWindows?
                        .contains(clickedWindow) == true
                    {
                        return event
                    }
                }

                self.hidePanel()
            }

            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}
