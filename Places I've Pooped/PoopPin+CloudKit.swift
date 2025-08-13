import Foundation
import CloudKit
import MapKit

extension PoopPin {
    static func fromCKRecord(_ r: CKRecord) -> PoopPin? {
        guard
            let userID = r["userID"] as? String,
            let userName = r["userName"] as? String,
            let createdAt = r["createdAt"] as? Date
        else { return nil }

        let coord: CLLocationCoordinate2D = {
            if let loc = r["location"] as? CLLocation { return loc.coordinate }
            let lat = r["latitude"] as? CLLocationDegrees ?? 0
            let lon = r["longitude"] as? CLLocationDegrees ?? 0
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }()

        return PoopPin(
            id: r.recordID.recordName,
            userID: userID,
            userName: userName,
            coordinate: coord,
            createdAt: createdAt,
            tpRating: r["tpRating"] as? Int ?? 0,
            cleanliness: r["cleanliness"] as? Int ?? 0,
            privacy: r["privacy"] as? Int ?? 0,
            plumbing: r["plumbing"] as? Int ?? 0,
            overallVibes: r["overallVibes"] as? Int ?? 0,
            comment: r["comment"] as? String,
            photoURL: r["photoURL"] as? String,
            userColorHex: r["userColor"] as? String
        )
    }
}
