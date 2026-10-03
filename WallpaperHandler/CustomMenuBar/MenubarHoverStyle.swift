//
//  MenubarHoverStyle.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//

import SwiftUI

struct MenubarHoverStyle<Content: View>: View {

    @ViewBuilder var content: Content
    var onHover: ((Bool) -> Void)? = nil
    @State private var isHovering = false

    var color: Color {
        isHovering ? .accentColor : .clear
    }

    var body: some View {
        content
            .onHover {
                isHovering = $0
                onHover?($0)
            }
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
            }
    }
}
