import SwiftUI

struct PoopPinSummaryView: View {
    let pin: PoopPin

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pin.locationDescription)
                .font(.headline)

            if !pin.comment.isEmpty {
                Text(pin.comment)
                    .font(.subheadline)
            }

            HStack(spacing: 12) {
                Text("TP: \(pin.tpRating)")
                Text("Cleanliness: \(pin.cleanliness)")
                Text("Privacy: \(pin.privacy)")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    PoopPinSummaryView(pin: PoopPin(
        id: "preview-id",
        userID: "user123",
        userName: "Preview User",
        groupID: "group123",
        coordinate: .init(latitude: 37.3349, longitude: -122.0090),
        tpRating: 4,
        cleanliness: 3,
        privacy: 5,
        plumbing: 3,
        overallVibes: 4,
        comment: "Nice stall, decent lighting.",
        userColor: .brown,
        locationDescription: "Public Library",
        photoURL: nil,
        createdAt: Date()
    ))
}
