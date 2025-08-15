//
//  PoopManager.swift
//  Places I've Pooped
//

import Foundation
import CloudKit
import CoreLocation
import SwiftUI
import Network
#if canImport(UIKit)
import UIKit
#endif

final class PoopManager: ObservableObject {
    @Published var poopPins: [PoopPin] = []
    @Published var lastAddedPin: PoopPin?            // MapView centers on this
    @Published var comments: [PoopComment] = []      // for PoopDetailView

    private let db = CKEnv.privateDB

    // Offline retry
    private var pendingRecords: [CKRecord] = []
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "PoopManager.Network")
    
    // Local persistence for debugging
    private let userDefaults = UserDefaults.standard
    private let localPinsKey = "PoopManager.localPins"

    init() { 
        // Simulator bypass for testing
        #if targetEnvironment(simulator)
        print("🖥️ Simulator: Setting up test poop data")
        print("🖥️ Simulator: Creating test poops...")
        self.poopPins = [
            PoopPin(
                id: "simulator-poop-1",
                userID: "simulator-user",
                groupID: "simulator-test-group",
                coordinate: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298), // Chicago
                tpRating: 4,
                cleanliness: 3,
                privacy: 5,
                plumbing: 4,
                overallVibes: 4,
                comment: "Test poop from simulator",
                userColor: .red,
                userName: "Simulator User",
                locationDescription: "Chicago, IL",
                createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
                photoURL: nil
            ),
            PoopPin(
                id: "virginia-friend-poop-1",
                userID: "virginia-friend",
                groupID: "simulator-test-group",
                coordinate: CLLocationCoordinate2D(latitude: 42.1539, longitude: -88.1362), // Barrington, IL
                tpRating: 3,
                cleanliness: 4,
                privacy: 3,
                plumbing: 5,
                overallVibes: 4,
                comment: "Test poop from Virginia friend",
                userColor: .blue,
                userName: "Virginia Friend",
                locationDescription: "Barrington, IL",
                createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
                photoURL: nil
            )
        ]
        print("🖥️ Simulator: Created \(self.poopPins.count) test poops")
        print("🖥️ Simulator: Poop IDs: \(self.poopPins.map { $0.id })")
        
        // Don't fetch from CloudKit in simulator
        return
        #endif
        
        startNetworkMonitor()
        
        // Listen for user color changes to refresh pins
        NotificationCenter.default.addObserver(
            forName: .userColorChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPinsForColorChange()
        }
        
        // Listen for group membership changes to refresh data
        NotificationCenter.default.addObserver(
            forName: .groupMembershipChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Group membership changed, refreshing poop data...")
            self?.fetchPoopPins()
        }
    }

    // MARK: - Pins

    func fetchPoopPins() {
        // Simulator bypass - don't fetch from CloudKit in simulator
        #if targetEnvironment(simulator)
        print("🖥️ Simulator: Skipping CloudKit fetch, using test data")
        return
        #endif
        
        print("🔍 fetchPoopPins: Starting fetch...")
        // Query both PoopPin and Poop record types to handle both schemas
        let recordTypes = ["PoopPin", "Poop"]
        let dbs: [CKDatabase] = [CKEnv.privateDB, CKEnv.publicDB]
        
        let group = DispatchGroup()
        var gathered: [PoopPin] = []
        let lock = NSLock()
        
        func appendMapped(_ pins: [PoopPin]) {
            lock.lock(); gathered.append(contentsOf: pins); lock.unlock()
        }
        
        for recordType in recordTypes {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            for db in dbs {
                group.enter()
                db.perform(query, inZoneWith: nil) { records, error in
                    if let error = error {
                        print("❌ fetchPoopPins \(recordType) from \(db == CKEnv.privateDB ? "private" : "public"): \(error.localizedDescription)")
                        group.leave()
                        return
                    }
                    
                    let mapped: [PoopPin] = (records ?? []).compactMap { record in
                        if recordType == "PoopPin" {
                            return PoopManager.pin(from: record)
                        } else {
                            return PoopManager.pinFromPoopRecord(record)
                        }
                    }
                    appendMapped(mapped)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            
            // Simulator bypass - don't overwrite test data
            #if targetEnvironment(simulator)
            print("🖥️ Simulator: Keeping existing test data, not overwriting with CloudKit results")
            return
            #endif
            
            // De-dupe by recordName and sort newest-first
            let unique = Dictionary(gathered.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let sorted = unique.values.sorted(by: { $0.createdAt > $1.createdAt })
            
            // Merge with any locally stored pins that haven't been saved to CloudKit yet
            let localPins = self.loadLocalPins()
            let allPins = sorted + localPins.filter { localPin in
                !sorted.contains { $0.id == localPin.id }
            }
            let finalSorted = allPins.sorted(by: { $0.createdAt > $1.createdAt })
            
            self.poopPins = finalSorted
            print("✅ fetchPoopPins: Loaded \(sorted.count) CloudKit poops + \(localPins.count) local poops = \(finalSorted.count) total")
            print("📊 All Poop Details:")
            for pin in finalSorted {
                print("  - ID: \(pin.id)")
                print("    User: \(pin.userName) (\(pin.userID))")
                print("    Group: \(pin.groupID ?? "none")")
                print("    Location: \(pin.locationDescription)")
                print("    Created: \(pin.createdAt)")
            }
        }
    }

    /// Delete a poop pin from CloudKit and local storage
    func deletePoopPin(_ pin: PoopPin) {
        print("🗑️ deletePoopPin: Deleting poop pin: \(pin.id)")
        
        // Remove from local array immediately (optimistic)
        DispatchQueue.main.async {
            self.poopPins.removeAll { $0.id == pin.id }
        }
        
        // Delete from CloudKit
        let recordID = CKRecord.ID(recordName: pin.id)
        let targetDB = pin.groupID != nil ? CKEnv.publicDB : self.db
        
        targetDB.delete(withRecordID: recordID) { [weak self] _, error in
            if let error = error {
                print("❌ Failed to delete poop pin from CloudKit: \(error.localizedDescription)")
                // Restore the pin if deletion failed
                DispatchQueue.main.async {
                    self?.poopPins.append(pin)
                }
            } else {
                print("✅ Successfully deleted poop pin: \(pin.id)")
                // Also remove from local storage
                self?.removeLocalPin(withID: pin.id)
            }
        }
    }

    /// Optimistic add → shows immediately, saves in background, replaces with server copy
    func addPoopPin(
        userID: String,
        userName: String,
        userColor: Color?,
        groupID: String?,
        coordinate: CLLocationCoordinate2D,
        locationDescription: String,
        tpRating: Int,
        cleanliness: Int,
        privacy: Int,
        plumbing: Int,
        overallVibes: Int,
        comment: String,
        photoURL: URL? = nil
    ) {
        print("➕ addPoopPin: Starting to add poop for user: \(userID)")
        print("➕ addPoopPin: User authenticated: \(!userID.isEmpty)")
        let local = PoopPin(
            id: "temp.\(UUID().uuidString)",
            userID: userID,
            groupID: groupID,
            coordinate: coordinate,
            tpRating: tpRating,
            cleanliness: cleanliness,
            privacy: privacy,
            plumbing: plumbing,
            overallVibes: overallVibes,
            comment: comment,
            userColor: userColor ?? .blue,
            userName: userName,
            locationDescription: locationDescription,
            createdAt: Date(),
            photoURL: photoURL
        )

        DispatchQueue.main.async {
            self.poopPins.insert(local, at: 0)
            self.lastAddedPin = local
        }

        let rec = CKRecord(recordType: "Poop")
        rec["userID"] = userID as CKRecordValue
        if let groupID { rec["groupID"] = groupID as CKRecordValue }
        rec["location"] = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        rec["locationDescription"] = locationDescription as CKRecordValue
        rec["tpRating"] = tpRating as CKRecordValue
        rec["cleanliness"] = cleanliness as CKRecordValue
        rec["privacy"] = privacy as CKRecordValue
        rec["plumbing"] = plumbing as CKRecordValue
        rec["overallVibes"] = overallVibes as CKRecordValue
        rec["comment"] = comment as CKRecordValue
        rec["userName"] = userName as CKRecordValue
        rec["createdAt"] = Date() as CKRecordValue
        if let userColor { 
            let hexString = ColorCoding.hexString(from: userColor)
            rec["userColorHex"] = hexString as CKRecordValue
        }
        if let photoURL { rec["photo"] = CKAsset(fileURL: photoURL) }

        // For group poops, save to public DB so other members can see them
        // For personal poops, save to private DB
        let targetDB = groupID != nil ? CKEnv.publicDB : self.db
        
        print("💾 Saving poop to \(groupID != nil ? "PUBLIC" : "PRIVATE") database")
        print("💾 Group ID: \(groupID ?? "none")")
        print("💾 User ID: \(userID)")
        
        targetDB.save(rec) { [weak self] saved, err in
            guard let self else { return }
            if let err {
                print("⚠️ addPoopPin save failed, will retry: \(err.localizedDescription)")
                print("⚠️ Error details: \(err)")
                self.enqueueForRetry(rec)
                // Save locally as backup to prevent data loss
                self.saveLocalPin(local)
                print("💾 Saved pin locally as backup: \(local.id)")
                return
            }
            guard let saved, let savedPin = PoopManager.pin(from: saved) else { 
                print("❌ Failed to create pin from saved record")
                // Save locally as backup
                self.saveLocalPin(local)
                print("💾 Saved pin locally as backup: \(local.id)")
                return 
            }
            DispatchQueue.main.async {
                // Remove from local storage since it's now in CloudKit
                self.removeLocalPin(withID: local.id)
                
                if let idx = self.poopPins.firstIndex(where: { $0.id == local.id }) {
                    self.poopPins[idx] = savedPin
                } else {
                    self.poopPins.insert(savedPin, at: 0)
                }
                self.lastAddedPin = savedPin
                print("✅ Successfully saved and updated pin: \(savedPin.id)")
            }
        }
    }

    private static func pin(from record: CKRecord) -> PoopPin? {
        guard
            let loc = record["location"] as? CLLocation,
            let tp = record["tpRating"] as? Int,
            let clean = record["cleanliness"] as? Int,
            let priv = record["privacy"] as? Int,
            let plum = record["plumbing"] as? Int,
            let vibes = record["overallVibes"] as? Int,
            let comment = record["comment"] as? String,
            let userID = record["userID"] as? String,
            let userName = record["userName"] as? String,
            let createdAt = (record["createdAt"] as? Date)
        else { return nil }

        let groupID = record["groupID"] as? String
        let locDesc = (record["locationDescription"] as? String) ?? ""
        let colorHex = (record["userColorHex"] as? String)
        let color = ColorCoding.color(fromHex: colorHex) ?? .blue
        let photoAsset = record["photo"] as? CKAsset
        let photoURL = photoAsset?.fileURL

        return PoopPin(
            id: record.recordID.recordName,
            userID: userID,
            groupID: groupID,
            coordinate: CLLocationCoordinate2D(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude),
            tpRating: tp,
            cleanliness: clean,
            privacy: priv,
            plumbing: plum,
            overallVibes: vibes,
            comment: comment,
            userColor: color,
            userName: userName,
            locationDescription: locDesc,
            createdAt: createdAt,
            photoURL: photoURL
        )
    }
    
    private static func pinFromPoopRecord(_ record: CKRecord) -> PoopPin? {
        guard record.recordType == "Poop" else { return nil }

        let coordinate: CLLocationCoordinate2D? = {
            if let loc = record["location"] as? CLLocation { return loc.coordinate }
            if let lat = record["latitude"] as? CLLocationDegrees,
               let lon = record["longitude"] as? CLLocationDegrees {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }()
        guard let coord = coordinate else { return nil }

        guard
            let userID   = record["userID"] as? String,
            let userName = record["userName"] as? String
        else { return nil }

        let createdAt    = (record["createdAt"] as? Date) ?? (record.creationDate ?? Date())
        let comment      = (record["comment"] as? String) ?? ""
        let locDesc      = (record["locationDescription"] as? String) ?? ""
        let groupID      = record["groupID"] as? String
        let tpRating     = record["tpRating"] as? Int ?? 0
        let cleanliness  = record["cleanliness"] as? Int ?? 0
        let privacy      = record["privacy"] as? Int ?? 0
        let plumbing     = record["plumbing"] as? Int ?? 0
        let overallVibes = record["overallVibes"] as? Int ?? 0

        let colorHex     = (record["userColor"] as? String) ?? (record["userColorHex"] as? String) ?? "#3366FF"
        let color        = ColorCoding.color(fromHex: colorHex) ?? .blue

        let assetURL  = (record["photo"] as? CKAsset)?.fileURL
        let stringURL = (record["photoURL"] as? String).flatMap(URL.init(string:))
        let photoURL  = assetURL ?? stringURL

        return PoopPin(
            id: record.recordID.recordName,
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

    // MARK: - Comments

    struct PoopComment: Identifiable {
        let id: String
        let poopID: String
        let userID: String
        let userName: String
        let text: String
        let createdAt: Date
    }

    // MARK: - Comments (group + friends visibility)

    func fetchComments(
        for poop: PoopPin,
        viewerID: String?,
        viewerFriendIDs: [String],
        viewerGroupID: String?
    ) {
        // Base: only comments for this poop
        let base = NSPredicate(format: "poopID == %@", poop.id)

        // Visibility: group OR friends-of-viewer OR viewer themself OR poop owner
        var ors: [NSPredicate] = [
            NSPredicate(format: "userID == %@", poop.userID)
        ]
        if let vid = viewerID {
            ors.append(NSPredicate(format: "userID == %@", vid))
        }
        if !viewerFriendIDs.isEmpty {
            ors.append(NSPredicate(format: "userID IN %@", viewerFriendIDs))
        }
        if let gid = viewerGroupID, !gid.isEmpty {
            ors.append(NSPredicate(format: "groupID == %@", gid))
        }

        let visibility = NSCompoundPredicate(orPredicateWithSubpredicates: ors)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [base, visibility])

        let q = CKQuery(recordType: "Comment", predicate: predicate)
        q.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        // Comments are shared → public DB
        let publicDB = CKEnv.publicDB
        publicDB.perform(q, inZoneWith: nil) { [weak self] recs, err in
            guard let self else { return }
            if let err { print("❌ fetchComments:", err.localizedDescription); return }
            let items: [PoopComment] = (recs ?? []).compactMap { r in
                guard
                    let poopID = r["poopID"] as? String,
                    let userID = r["userID"] as? String,
                    let userName = r["userName"] as? String,
                    let text = r["text"] as? String,
                    let createdAt = r["createdAt"] as? Date
                else { return nil }
                return PoopComment(id: r.recordID.recordName,
                                   poopID: poopID,
                                   userID: userID,
                                   userName: userName,
                                   text: text,
                                   createdAt: createdAt)
            }
            DispatchQueue.main.async { self.comments = items }
        }
    }

    func addComment(
        for poop: PoopPin,
        userID: String,
        userName: String,
        text: String,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let r = CKRecord(recordType: "Comment")
        r["poopID"] = poop.id as CKRecordValue
        r["userID"] = userID as CKRecordValue
        r["userName"] = userName as CKRecordValue
        r["text"] = text as CKRecordValue
        r["createdAt"] = Date() as CKRecordValue
        if let gid = poop.groupID { r["groupID"] = gid as CKRecordValue } // scope to group when applicable

        let publicDB = CKEnv.publicDB
        publicDB.save(r) { [weak self] saved, err in
            guard let self else { return }
            if let err {
                DispatchQueue.main.async { completion?(.failure(err)) }
                return
            }
            let item = PoopComment(id: saved?.recordID.recordName ?? UUID().uuidString,
                                   poopID: poop.id,
                                   userID: userID,
                                   userName: userName,
                                   text: text,
                                   createdAt: Date())
            DispatchQueue.main.async {
                self.comments.append(item)  // optimistic append
                completion?(.success(()))
            }
        }
    }


    // MARK: - Offline retry

    private func enqueueForRetry(_ record: CKRecord) {
        queue.async { self.pendingRecords.append(record) }
    }
    
    private func getTargetDatabase(for record: CKRecord) -> CKDatabase {
        // Check if this is a group poop by looking for groupID
        if let groupID = record["groupID"] as? String, !groupID.isEmpty {
            return CKEnv.publicDB
        }
        return self.db
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if path.status == .satisfied { self.flushPending() }
        }
        monitor.start(queue: queue)
    }

    private func flushPending() {
        guard !pendingRecords.isEmpty else { return }
        let batch = pendingRecords
        pendingRecords.removeAll()

        print("🔄 Flushing \(batch.count) pending records...")

        for rec in batch {
            let targetDB = self.getTargetDatabase(for: rec)
            targetDB.save(rec) { [weak self] saved, err in
                guard let self else { return }
                if let err {
                    print("♻️ retry failed, requeue: \(err.localizedDescription)")
                    print("♻️ Error details: \(err)")
                    self.enqueueForRetry(rec)
                    return
                }
                if let saved, let pin = PoopManager.pin(from: saved) {
                    DispatchQueue.main.async {
                        if let idx = self.poopPins.firstIndex(where: { $0.id == rec.recordID.recordName }) {
                            self.poopPins[idx] = pin
                        } else {
                            self.poopPins.insert(pin, at: 0)
                        }
                        self.lastAddedPin = pin
                        print("✅ Retry successful for pin: \(pin.id)")
                    }
                } else {
                    print("❌ Failed to create pin from retry saved record")
                }
            }
        }
    }
    
    // MARK: - Color Change Refresh
    
    private func refreshPinsForColorChange() {
        // Update colors for existing pins without refetching from CloudKit
        Task { @MainActor in
            // Update the colors of existing pins based on current group membership
            await updatePinColors()
        }
    }
    
    private func updatePinColors() async {
        // Get current user's group color
        guard let userID = UserDefaults.standard.string(forKey: "auth.user.recordName") ?? 
                          UserDefaults.standard.string(forKey: "auth.apple.userID") else {
            return
        }
        
        // Update pins for the current user
        for i in 0..<poopPins.count {
            if poopPins[i].userID == userID {
                // Get the user's current group color
                let newColor = await getUserCurrentColor()
                if let newColor = newColor {
                    poopPins[i] = PoopPin(
                        id: poopPins[i].id,
                        userID: poopPins[i].userID,
                        groupID: poopPins[i].groupID,
                        coordinate: poopPins[i].coordinate,
                        tpRating: poopPins[i].tpRating,
                        cleanliness: poopPins[i].cleanliness,
                        privacy: poopPins[i].privacy,
                        plumbing: poopPins[i].plumbing,
                        overallVibes: poopPins[i].overallVibes,
                        comment: poopPins[i].comment,
                        userColor: newColor,
                        userName: poopPins[i].userName,
                        locationDescription: poopPins[i].locationDescription,
                        createdAt: poopPins[i].createdAt,
                        photoURL: poopPins[i].photoURL
                    )
                }
            }
        }
    }
    
    private func getUserCurrentColor() async -> Color? {
        // Try to get color from UserDefaults first
        if let colorHex = UserDefaults.standard.string(forKey: "user.color.hex") {
            return ColorCoding.color(fromHex: colorHex)
        }
        
        // Fallback to default blue
        return .blue
    }
    
    // MARK: - Local Persistence (for debugging)
    
    private func saveLocalPin(_ pin: PoopPin) {
        var localPins = loadLocalPins()
        localPins.append(pin)
        saveLocalPins(localPins)
    }
    
    private func removeLocalPin(withID id: String) {
        var localPins = loadLocalPins()
        localPins.removeAll { $0.id == id }
        saveLocalPins(localPins)
    }
    
    private func loadLocalPins() -> [PoopPin] {
        guard let data = userDefaults.data(forKey: localPinsKey),
              let pins = try? JSONDecoder().decode([PoopPin].self, from: data) else {
            return []
        }
        return pins
    }
    
    private func saveLocalPins(_ pins: [PoopPin]) {
        guard let data = try? JSONEncoder().encode(pins) else { return }
        userDefaults.set(data, forKey: localPinsKey)
    }
}

// MARK: - Color coding helpers
enum ColorCoding {
    static func hexString(from color: Color) -> String {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "#007AFF" }
        let R = Int(round(r * 255)), G = Int(round(g * 255)), B = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", R, G, B)
        #else
        return "#007AFF"
        #endif
    }

    static func color(fromHex hex: String?) -> Color? {
        guard let hex else { return nil }
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        guard let rgb = UInt32(cleaned, radix: 16) else { return nil }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        #if canImport(UIKit)
        return Color(UIColor(red: r, green: g, blue: b, alpha: 1))  // labeled args ✅
        #else
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: 1)
        #endif
    }
}
