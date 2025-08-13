//
//  PoopPin+CloudKit.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/8/25.
//

import Foundation
import CloudKit
import MapKit
import SwiftUI

extension PoopPin {
    /// Build a PoopPin from a CloudKit record
    static func fromCKRecord(_ r: CKRecord) -> PoopPin? {
        guard
            let userID = r["userID"] as? String,
            let userName = r["userName"] as? String,
            let loc = r["location"] as? CLLocation
        else { return nil }

        let groupID = r["groupID"] as? String
        let createdAt = (r["createdAt"] as? Date) ?? Date()
        let locationDescription = (r["locationDescription"] as? String) ?? ""
        let tp = r["tpRating"] as? Int ?? 0
        let clean = r["cleanliness"] as? Int ?? 0
        let priv = r["privacy"] as? Int ?? 0
        let plum = r["plumbing"] as? Int ?? 0
        let vibes = r["overallVibes"] as? Int ?? 0
        let comment = r["comment"] as? String ?? ""

        // Color is stored as a hex string in userColorHex
        let colorHex = r["userColorHex"] as? String
        let color = ColorCoding.color(fromHex: colorHex) ?? .blue

        // Photo is stored as CKAsset("photo")
        let asset = r["photo"] as? CKAsset
        let photoURL = asset?.fileURL

        return PoopPin(
            id: r.recordID.recordName,
            userID: userID,
            groupID: groupID,
            coordinate: CLLocationCoordinate2D(latitude: loc.coordinate.latitude,
                                               longitude: loc.coordinate.longitude),
            tpRating: tp,
            cleanliness: clean,
            privacy: priv,
            plumbing: plum,
            overallVibes: vibes,
            comment: comment,
            userColor: color,
            userName: userName,
            locationDescription: locationDescription,
            createdAt: createdAt,
            photoURL: photoURL
        )
    }
}
