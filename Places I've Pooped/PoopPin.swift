//
//  PoopPin.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/4/25.
//

import Foundation
import CoreLocation
import SwiftUI

struct PoopPin: Identifiable, Codable {
    let id: String
    let userID: String
    let groupID: String?
    let coordinate: CLLocationCoordinate2D
    let tpRating: Int
    let cleanliness: Int
    let privacy: Int
    let plumbing: Int
    let overallVibes: Int
    let comment: String
    let userColor: Color
    let userName: String
    let locationDescription: String
    let createdAt: Date
    let photoURL: URL?
    
    // MARK: - Regular Initializer
    init(
        id: String,
        userID: String,
        groupID: String?,
        coordinate: CLLocationCoordinate2D,
        tpRating: Int,
        cleanliness: Int,
        privacy: Int,
        plumbing: Int,
        overallVibes: Int,
        comment: String,
        userColor: Color,
        userName: String,
        locationDescription: String,
        createdAt: Date,
        photoURL: URL?
    ) {
        self.id = id
        self.userID = userID
        self.groupID = groupID
        self.coordinate = coordinate
        self.tpRating = tpRating
        self.cleanliness = cleanliness
        self.privacy = privacy
        self.plumbing = plumbing
        self.overallVibes = overallVibes
        self.comment = comment
        self.userColor = userColor
        self.userName = userName
        self.locationDescription = locationDescription
        self.createdAt = createdAt
        self.photoURL = photoURL
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, userID, groupID, tpRating, cleanliness, privacy, plumbing, overallVibes, comment, userName, locationDescription, createdAt, photoURL
        case latitude, longitude, userColorHex
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        tpRating = try container.decode(Int.self, forKey: .tpRating)
        cleanliness = try container.decode(Int.self, forKey: .cleanliness)
        privacy = try container.decode(Int.self, forKey: .privacy)
        plumbing = try container.decode(Int.self, forKey: .plumbing)
        overallVibes = try container.decode(Int.self, forKey: .overallVibes)
        comment = try container.decode(String.self, forKey: .comment)
        let colorHex = try container.decode(String.self, forKey: .userColorHex)
        userColor = ColorCoding.color(fromHex: colorHex) ?? .blue
        userName = try container.decode(String.self, forKey: .userName)
        locationDescription = try container.decode(String.self, forKey: .locationDescription)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        photoURL = try container.decodeIfPresent(URL.self, forKey: .photoURL)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(groupID, forKey: .groupID)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(tpRating, forKey: .tpRating)
        try container.encode(cleanliness, forKey: .cleanliness)
        try container.encode(privacy, forKey: .privacy)
        try container.encode(plumbing, forKey: .plumbing)
        try container.encode(overallVibes, forKey: .overallVibes)
        try container.encode(comment, forKey: .comment)
        try container.encode(ColorCoding.hexString(from: userColor), forKey: .userColorHex)
        try container.encode(userName, forKey: .userName)
        try container.encode(locationDescription, forKey: .locationDescription)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(photoURL, forKey: .photoURL)
    }
}
