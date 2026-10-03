//
//  MenubarButton.swift
//  WallpaperHandler
//
//  Created by Aryan Rogye on 10/1/26.
//


import SwiftUI

struct MenubarButton: View {

    let label: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            Text(label)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 12)
        }
        .buttonStyle(MenubarButtonStyle())
    }
}
