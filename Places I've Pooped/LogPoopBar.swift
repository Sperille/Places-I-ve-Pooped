import SwiftUI

struct LogPoopBar: View {
    var tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Log Poop")
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .opacity(0.9)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#6B4F3B")) // Your brown
            )
        }
        .buttonStyle(.plain)
        .shadow(radius: 8, y: 2)
        .accessibilityLabel("Open Log Poop")
    }
}
