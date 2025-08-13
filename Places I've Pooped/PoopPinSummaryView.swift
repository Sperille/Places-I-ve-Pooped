//
//  PoopPinSummaryView.swift
//  Places I've Pooped
//
//  Styled for Dashboard feed: Name, Location, Comment, Numeric Ratings
//

import SwiftUI

struct PoopPinSummaryView: View {
    let pin: PoopPin

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name
            Text(pin.userName)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)

            // Location
            if !pin.locationDescription.isEmpty {
                Text(pin.locationDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Comment
            if !pin.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(pin.comment)
                    .font(.body)
            }

            // Ratings (all categories, numeric)
            VStack(alignment: .leading, spacing: 6) {
                RatingNumberRow(title: "Toilet Paper", value: pin.tpRating)
                RatingNumberRow(title: "Cleanliness", value: pin.cleanliness)
                RatingNumberRow(title: "Privacy", value: pin.privacy)
                RatingNumberRow(title: "Plumbing", value: pin.plumbing)
                RatingNumberRow(title: "Overall Vibes", value: pin.overallVibes)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RatingNumberRow: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
