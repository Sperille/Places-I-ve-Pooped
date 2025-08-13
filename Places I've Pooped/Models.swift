//
//  Models.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/5/25.
//

import SwiftUI
import CoreLocation

struct PoopReview: Identifiable {
    let id = UUID()
    let userName: String
    let location: String
    let comment: String
}

struct PoopComment: Identifiable {
    let id: String
    let poopID: String
    let userID: String
    let userName: String
    let text: String
    let createdAt: Date
}

