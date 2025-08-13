//
//  Places I've Pooped
//
//  Created by Steven Perille on 8/4/25.
//

import Foundation
import CloudKit
import CoreLocation
import SwiftUI

extension PoopManager {

    // Feed scopes used by the views
    enum PoopFeedScope: Equatable {
        case mine(String)         // userID
        case group(String)        // groupID
        case friends([String])    // friend userIDs
    }

    /// Load pins for a given scope from both `Poop` and `PoopPin` record types.
    /// Calls `completion` on the main queue with newest-first results.
    func loadPins(scope: PoopFeedScope, completion: @escaping ([PoopPin]) -> Void) {
        // Build predicate per scope
        let predicate: NSPredicate
        switch scope {
        case .mine(let userID):
            predicate = NSPredicate(format: "userID == %@", userID)
        case .group(let groupID):
            predicate = NSPredicate(format: "groupID == %@", groupID)
        case .friends(let ids):
            guard !ids.isEmpty else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            predicate = NSPredicate(format: "userID IN %@", ids)
        }

        let recordTypes = ["PoopPin", "Poop"] // query both schemas
        let dbs: [CKDatabase] = [
            CKEnv.privateDB,
            CKEnv.publicDB
        ]

        let group = DispatchGroup()
        var gathered: [PoopPin] = []
        let lock = NSLock()

        func appendMapped(_ pins: [PoopPin]) {
            lock.lock(); gathered.append(contentsOf: pins); lock.unlock()
        }

        for rt in recordTypes {
            let query = CKQuery(recordType: rt, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            for db in dbs {
                group.enter()
                db.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                    switch result {
                    case .success(let queryResult):
                        let records = queryResult.matchResults.compactMap { _, recordResult in
                            switch recordResult {
                            case .success(let record):
                                return record
                            case .failure:
                                return nil
                            }
                        }
                        let mapped: [PoopPin] = records.compactMap { r in
                            if rt == "PoopPin" {
                                return Self.feed_mapPoopPinRecord(r) // local, not private elsewhere
                            } else {
                                return Self.feed_mapPoopRecord(r)
                            }
                        }
                        appendMapped(mapped)
                    case .failure:
                        // Handle error if needed
                        break
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // De-dupe by recordName and sort newest-first
            let unique = Dictionary(gathered.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let sorted = unique.values.sorted(by: { $0.createdAt > $1.createdAt })
            completion(sorted)
        }
    }
}

// MARK: - Private mapping for `Poop` & `PoopPin` records (file-scoped, no external deps)
private extension PoopManager {

    static func feed_mapPoopRecord(_ r: CKRecord) -> PoopPin? {
        guard r.recordType == "Poop" else { return nil }

        let coordinate: CLLocationCoordinate2D? = {
            if let loc = r["location"] as? CLLocation { return loc.coordinate }
            if let lat = r["latitude"] as? CLLocationDegrees,
               let lon = r["longitude"] as? CLLocationDegrees {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }()
        guard let coord = coordinate else { return nil }

        guard
            let userID   = r["userID"] as? String,
            let userName = r["userName"] as? String
        else { return nil }

        let createdAt    = (r["createdAt"] as? Date) ?? (r.creationDate ?? Date())
        let comment      = (r["comment"] as? String) ?? ""
        let locDesc      = (r["locationDescription"] as? String) ?? ""
        let groupID      = r["groupID"] as? String
        let tpRating     = r["tpRating"] as? Int ?? 0
        let cleanliness  = r["cleanliness"] as? Int ?? 0
        let privacy      = r["privacy"] as? Int ?? 0
        let plumbing     = r["plumbing"] as? Int ?? 0
        let overallVibes = r["overallVibes"] as? Int ?? 0

        let colorHex     = (r["userColor"] as? String) ?? (r["userColorHex"] as? String) ?? "#3366FF"
        let color        = ColorCoding.color(fromHex: colorHex) ?? .blue

        let assetURL  = (r["photo"] as? CKAsset)?.fileURL
        let stringURL = (r["photoURL"] as? String).flatMap(URL.init(string:))
        let photoURL  = assetURL ?? stringURL

        return PoopPin(
            id: r.recordID.recordName,
            userID: userID,
            groupID: groupID,
            coordinate: coord,
            tpRating: tpRating,
            cleanliness: cleanliness,
            privacy: privacy,
            plumbing: plumbing,
            overallVibes: overallVibes,
            comment: comment,
            userColor: color,
            userName: userName,
            locationDescription: locDesc,
            createdAt: createdAt,
            photoURL: photoURL
        )
    }

    static func feed_mapPoopPinRecord(_ r: CKRecord) -> PoopPin? {
        guard r.recordType == "PoopPin" else { return nil }

        let coordinate: CLLocationCoordinate2D? = {
            if let loc = r["location"] as? CLLocation { return loc.coordinate }
            if let lat = r["latitude"] as? CLLocationDegrees,
               let lon = r["longitude"] as? CLLocationDegrees {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }()
        guard let coord = coordinate else { return nil }

        guard
            let userID   = r["userID"] as? String,
            let userName = r["userName"] as? String
        else { return nil }

        let createdAt    = (r["createdAt"] as? Date) ?? (r.creationDate ?? Date())
        let comment      = (r["comment"] as? String) ?? ""
        let locDesc      = (r["locationDescription"] as? String) ?? ""
        let groupID      = r["groupID"] as? String
        let tpRating     = r["tpRating"] as? Int ?? 0
        let cleanliness  = r["cleanliness"] as? Int ?? 0
        let privacy      = r["privacy"] as? Int ?? 0
        let plumbing     = r["plumbing"] as? Int ?? 0
        let overallVibes = r["overallVibes"] as? Int ?? 0

        // In PoopPin, the color is commonly stored as `userColorHex`; accept `userColor` as fallback.
        let colorHex     = (r["userColorHex"] as? String) ?? (r["userColor"] as? String) ?? "#3366FF"
        let color        = ColorCoding.color(fromHex: colorHex) ?? .blue

        // In PoopPin, photo is usually a CKAsset under key `photo`
        let photoURL     = (r["photo"] as? CKAsset)?.fileURL

        return PoopPin(
            id: r.recordID.recordName,
            userID: userID,
            groupID: groupID,
            coordinate: coord,
            tpRating: tpRating,
            cleanliness: cleanliness,
            privacy: privacy,
            plumbing: plumbing,
            overallVibes: overallVibes,
            comment: comment,
            userColor: color,
            userName: userName,
            locationDescription: locDesc,
            createdAt: createdAt,
            photoURL: photoURL
        )
    }


}
