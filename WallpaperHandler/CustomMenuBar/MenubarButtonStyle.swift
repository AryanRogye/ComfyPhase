//
//  MenubarButtonStyle.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import SwiftUI

struct MenubarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenubarHoverStyle {
            configuration.label
        }
    }
}
