//
//  PoopPin.swift
//  Places I've Pooped
//

import Foundation
import CoreLocation
import SwiftUI

struct PoopPin: Identifiable {
    let id: String
    let userID: String
    let groupID: String?
    let coordinate: CLLocationCoordinate2D
    let tpRating: Int
    let cleanliness: Int
    let privacy: Int
    let comment: String
    let userColor: Color
    let userName: String
    let locationDescription: String
    let createdAt: Date
}
