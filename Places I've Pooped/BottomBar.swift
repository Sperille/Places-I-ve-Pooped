//
//  BottomBar.swift
//  Apple Music–style static bottom bar
//

import SwiftUI

struct BottomBar: View {
    @Binding var current: Screen

    var body: some View {
        HStack(spacing: 8) {
            BottomBarItem(icon: "speedometer", label: "Dashboard",
                          isSelected: current == .dashboard) { current = .dashboard }

            BottomBarItem(icon: "map.fill", label: "Map",
                          isSelected: current == .map) { current = .map }

            BottomBarItem(icon: "person.3.fill", label: "Groups",
                          isSelected: current == .groups) { current = .groups }

            BottomBarItem(icon: "person.2.fill", label: "Friends",
                          isSelected: current == .friends) { current = .friends }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(radius: 8, y: 2)
    }
}

private struct BottomBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.25))
                            )
                    } else { Color.clear }
                }
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.primary : .secondary)
        .contentShape(Rectangle())
    }
}
