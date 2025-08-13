//
//  BottomBar.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/8/25.
//

import SwiftUI

struct BottomBar: View {
    @Binding var current: Screen

    var body: some View {
        HStack(spacing: 8) {
            item(.dashboard, icon: "gauge.medium", title: "Dashboard")
            item(.map,       icon: "map.fill",       title: "Map")
            item(.groups,    icon: "person.3.fill",  title: "Groups")
            item(.friends,   icon: "person.2.fill",  title: "Friends")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.12)))
        .shadow(radius: 8, y: 2)
    }

    @ViewBuilder
    private func item(_ screen: Screen, icon: String, title: String) -> some View {
        let selected = current == screen
        Button { current = screen } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.18))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25)))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.primary : .secondary)
    }
}
