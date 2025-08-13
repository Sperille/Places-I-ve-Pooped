//
//  PoopManager+CommentsScoped.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/9/25.
//


//
//  PoopManager+CommentsScoped.swift
//  Places I've Pooped
//
//  Per-poop comments APIs that DO NOT touch the shared `comments` array.
//  Used by PoopDetailView to avoid cross-poop bleed.
//

import Foundation
import CloudKit

extension PoopManager {

    /// Fetch comments ONLY for the given poopID (merged from public + private DBs).
    func fetchCommentsScoped(for poopID: String, completion: @escaping ([PoopComment]) -> Void) {
        let dbs: [CKDatabase] = [CKEnv.publicDB, CKEnv.privateDB]
        let predicate = NSPredicate(format: "poopID == %@", poopID)
        let query = CKQuery(recordType: "PoopComment", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let group = DispatchGroup()
        var bucket: [PoopComment] = []
        let lock = NSLock()

        func map(_ r: CKRecord) -> PoopComment? {
            let id = r.recordID.recordName
            let userID = (r["userID"] as? String) ?? "unknown"
            let userName = (r["userName"] as? String) ?? "User"
            let text = (r["text"] as? String) ?? ""
            let createdAt = (r["createdAt"] as? Date) ?? (r.creationDate ?? Date())
            return PoopComment(id: id, poopID: poopID, userID: userID, userName: userName, text: text, createdAt: createdAt)
        }

        for db in dbs {
            group.enter()
            db.perform(query, inZoneWith: nil) { records, _ in
                let mapped = (records ?? []).compactMap(map)
                lock.lock(); bucket.append(contentsOf: mapped); lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // De-dupe by recordName then sort ascending by createdAt
            let unique = Dictionary(bucket.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let sorted = unique.values.sorted(by: { $0.createdAt < $1.createdAt })
            completion(sorted)
        }
    }

    /// Save a new comment for a poop (tries public DB first, falls back to private DB).
    func addCommentScoped(for poop: PoopPin,
                          userID: String,
                          userName: String,
                          text: String,
                          completion: @escaping (Bool) -> Void) {
        let rec = CKRecord(recordType: "PoopComment")
        rec["poopID"] = poop.id as CKRecordValue
        rec["userID"] = userID as CKRecordValue
        rec["userName"] = userName as CKRecordValue
        rec["text"] = text as CKRecordValue
        rec["createdAt"] = Date() as CKRecordValue

        // Save to public first so groups can see it; if that fails, try private.
        CKEnv.publicDB.save(rec) { _, err in
            if err == nil {
                DispatchQueue.main.async { completion(true) }
            } else {
                CKEnv.privateDB.save(rec) { _, err2 in
                    DispatchQueue.main.async { completion(err2 == nil) }
                }
            }
        }
    }
}
