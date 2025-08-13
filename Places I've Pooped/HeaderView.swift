//
//  HeaderView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/3/25.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var menuState: MenuState

    // Optional: pass a title if you want one centered/leading later
    var title: String? = nil

    var body: some View {
        HStack {
            if let title {
                Text(title)
                    .font(.title2.bold())
                Spacer()
            } else {
                Spacer()
            }

            Button {
                // Navigate to AccountView
                menuState.currentScreen = .account
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "#6B4F3B"))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
}
