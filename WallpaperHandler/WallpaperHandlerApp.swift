//
//  WallpaperHandlerApp.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 9/30/26.
//

import SwiftUI

@main
struct WallpaperHandlerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { EmptyView().destroyViewWindow() }
    }
}

