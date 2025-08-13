//
//  LogPoopBar.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/8/25.
//


import SwiftUI

struct LogPoopBar: View {
    var tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack {
                Spacer() // ✅ center content
                Text("🚽 Log Poop") // ✅ emoji + centered
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(poopColor)
            )
        }
        .buttonStyle(.plain)
        .shadow(radius: 8, y: 2)
        .accessibilityLabel("Open Log Poop")
    }
}
