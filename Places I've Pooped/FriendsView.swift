import SwiftUI

struct FriendsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Friends").font(.title.bold())
            Text("This is a placeholder. Hook up your real friends list here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding()
    }
}
