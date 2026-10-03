//
//  MenubarSection.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//


import SwiftUI

struct MenubarSection<Header: View, Content: View>: View {

    @ViewBuilder var content: Content
    @ViewBuilder var header: Header

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
                .padding(.horizontal, 12)
            content
        }
    }
}
