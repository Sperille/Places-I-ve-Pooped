//
//  StarRatingView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/3/25.
//

import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var label: String

    var body: some View {
        HStack {
            Text(label)
                .bold()
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            rating = star
                        }
                }
            }
        }
    }
}
