//
//  RatingView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/4/25.
//

import SwiftUI

struct RatingView: View {
    let title: String
    @Binding var rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { number in
                    Image(systemName: number <= rating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            rating = number
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
