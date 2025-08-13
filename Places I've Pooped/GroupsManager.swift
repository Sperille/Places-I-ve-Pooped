//
//  GroupsManager.swift
//  Places I've Pooped
//

import Foundation
import CloudKit
import SwiftUI



final class GroupsManager: ObservableObject {
    @Published var members: [GroupMember] = []
    @Published var currentGroupID: String?
    @Published var currentGroupName: String?

    private let privateDB = CKEnv.privateDB
    private let publicDB  = CKEnv.publicDB

    // UserDefaults keys for persistence
    private let kGroupIDKey   = "groups.current.id"
    private let kGroupNameKey = "groups.current.name"
    
    // Reference to AuthManager for user info
    private var authManager: AuthManager?
    
    func setAuthManager(_ auth: AuthManager) {
        self.authManager = auth
    }

    init() {
        // Restore persisted group selection
        let d = UserDefaults.standard
        self.currentGroupID = d.string(forKey: kGroupIDKey)
        self.currentGroupName = d.string(forKey: kGroupNameKey)
        if let gid = currentGroupID {
            fetchCurrentGroupName()
            fetchMembers(groupID: gid)
        }
    }

    // MARK: - Create Group (PUBLIC DB)
    func createGroup(name: String, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(NSError(
                domain: "Group",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Group name required."]
            )))
            return
        }

        // Check for existing group with same name (case-insensitive)
        let predicate = NSPredicate(format: "name == %@", trimmed)
        let query = CKQuery(recordType: "Group", predicate: predicate)
        
        publicDB.perform(query, inZoneWith: nil) { [weak self] existingRecords, error in
            if let error = error {
                print("❌ Error checking for existing group: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // If group with same name exists, return error
            if let existingRecords = existingRecords, !existingRecords.isEmpty {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "Group",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "A group with this name already exists."]
                    )))
                }
                return
            }
            
            // Proceed with creating the group
            let (userID, userName) = self?.currentUserIdentifier() ?? ("", "User")

            let record = CKRecord(recordType: "Group")
            record["name"] = trimmed as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            record["ownerID"] = userID as CKRecordValue
            record["inviteCode"] = Self.generateInviteCode() as CKRecordValue

            self?.publicDB.save(record) { [weak self] rec, error in
                if let error = error {
                    print("❌ CloudKit Error: \(error.localizedDescription)")
                    print("❌ Error Code: \((error as NSError).code)")
                    print("❌ Error Domain: \((error as NSError).domain)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                guard let rec = rec else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "Group",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "No record returned from CloudKit."]
                        )))
                    }
                    return
                }
                // Add creator as first member
                self?.ensureMembership(groupID: rec.recordID.recordName, userID: userID, userName: userName) { _ in
                    DispatchQueue.main.async {
                        self?.currentGroupID = rec.recordID.recordName
                        self?.currentGroupName = trimmed
                        self?.persistSelection()
                        self?.fetchMembers(groupID: rec.recordID.recordName)
                        self?.fetchCurrentGroupName()
                        completion(.success(rec.recordID))
                    }
                }
            }
        }
    }

    // MARK: - Search (PUBLIC DB; Production-safe predicate)
    func searchGroups(query: String, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { completion(.success([])); return }

        // CloudKit Production: use BEGINSWITH and merge a few casings.
        let terms = Array(Set([q, q.capitalized, q.lowercased()]))
        var pending = terms.count
        var results: [CKRecord] = []
        let lock = NSLock()

        func finishSuccess() {
            // De-dupe by recordID
            let unique = Dictionary(grouping: results, by: { $0.recordID }).compactMap { $0.value.first }
            completion(.success(unique))
        }

        for term in terms {
            let predicate = NSPredicate(format: "name BEGINSWITH %@", term)
            let ckQuery = CKQuery(recordType: "Group", predicate: predicate)
            let op = CKQueryOperation(query: ckQuery)
            op.resultsLimit = 50
            op.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    lock.lock(); results.append(record); lock.unlock()
                }
            }
            op.queryResultBlock = { final in
                DispatchQueue.main.async {
                    pending -= 1
                    if pending == 0 {
                        switch final {
                        case .success:
                            finishSuccess()
                        case .failure(let err):
                            completion(.failure(err))
                        }
                    }
                }
            }
            publicDB.add(op)
        }
    }

    // MARK: - Join / Leave
    func joinGroup(groupID: String, name: String? = nil, userColor: Color? = nil) {
        let (userID, userName) = self.currentUserIdentifier()

        ensureMembership(groupID: groupID, userID: userID, userName: userName, userColor: userColor) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentGroupID = groupID
                if let name { self?.currentGroupName = name }
                self?.persistSelection()
                self?.fetchMembers(groupID: groupID)
                self?.fetchCurrentGroupName()
                
                // Refresh poop data to show historical group poops
                print("🔄 User joined group \(groupID), refreshing poop data...")
                // This will trigger a refresh of poop data to show historical group poops
                NotificationCenter.default.post(name: .groupMembershipChanged, object: nil)
            }
        }
    }

    func leaveGroup(completion: (() -> Void)? = nil) {
        currentGroupID = nil
        currentGroupName = nil
        members = []
        // Clear persisted selection
        let d = UserDefaults.standard
        d.removeObject(forKey: kGroupIDKey)
        d.removeObject(forKey: kGroupNameKey)
        completion?()
    }
    
    // MARK: - Delete Group (for cleanup)
    
    func deleteGroup(groupID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🗑️ Deleting group: \(groupID)")
        
        // First, delete all group members
        let memberPredicate = NSPredicate(format: "groupID == %@", groupID)
        let memberQuery = CKQuery(recordType: "GroupMember", predicate: memberPredicate)
        
        publicDB.perform(memberQuery, inZoneWith: nil) { [weak self] memberRecords, memberError in
            if let memberError = memberError {
                print("❌ Error fetching group members for deletion: \(memberError.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(memberError))
                }
                return
            }
            
            // Delete all member records
            let memberGroup = DispatchGroup()
            var memberErrors: [Error] = []
            
            for memberRecord in memberRecords ?? [] {
                memberGroup.enter()
                self?.publicDB.delete(withRecordID: memberRecord.recordID) { _, error in
                    if let error = error {
                        print("❌ Error deleting member record: \(error.localizedDescription)")
                        memberErrors.append(error)
                    } else {
                        print("✅ Deleted member record: \(memberRecord.recordID.recordName)")
                    }
                    memberGroup.leave()
                }
            }
            
            memberGroup.notify(queue: .main) {
                // Now delete the group record
                let groupRecordID = CKRecord.ID(recordName: groupID)
                self?.publicDB.delete(withRecordID: groupRecordID) { _, groupError in
                    if let groupError = groupError {
                        print("❌ Error deleting group record: \(groupError.localizedDescription)")
                        DispatchQueue.main.async {
                            completion(.failure(groupError))
                        }
                        return
                    }
                    
                    print("✅ Successfully deleted group: \(groupID)")
                    
                    // If this was the current group, clear it
                    if self?.currentGroupID == groupID {
                        self?.leaveGroup()
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    // MARK: - Bulk Delete Groups (for cleanup)
    
    func deleteAllGroupsWithName(_ groupName: String, completion: @escaping (Result<Int, Error>) -> Void) {
        print("🗑️ Deleting all groups with name: \(groupName)")
        
        let predicate = NSPredicate(format: "name == %@", groupName)
        let query = CKQuery(recordType: "Group", predicate: predicate)
        
        publicDB.perform(query, inZoneWith: nil) { [weak self] groupRecords, error in
            if let error = error {
                print("❌ Error fetching groups for deletion: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let groupRecords = groupRecords, !groupRecords.isEmpty else {
                print("ℹ️ No groups found with name: \(groupName)")
                DispatchQueue.main.async {
                    completion(.success(0))
                }
                return
            }
            
            print("🗑️ Found \(groupRecords.count) groups to delete")
            
            let deleteGroup = DispatchGroup()
            var deletedCount = 0
            var errors: [Error] = []
            
            for groupRecord in groupRecords {
                deleteGroup.enter()
                let groupID = groupRecord.recordID.recordName
                
                // Delete the group and all its members
                self?.deleteGroup(groupID: groupID) { result in
                    switch result {
                    case .success:
                        deletedCount += 1
                        print("✅ Deleted group \(deletedCount)/\(groupRecords.count): \(groupID)")
                    case .failure(let error):
                        errors.append(error)
                        print("❌ Failed to delete group: \(groupID) - \(error.localizedDescription)")
                    }
                    deleteGroup.leave()
                }
            }
            
            deleteGroup.notify(queue: .main) {
                if errors.isEmpty {
                    print("✅ Successfully deleted \(deletedCount) groups with name: \(groupName)")
                    completion(.success(deletedCount))
                } else {
                    print("⚠️ Deleted \(deletedCount) groups but encountered \(errors.count) errors")
                    completion(.failure(errors.first!))
                }
            }
        }
    }

    // MARK: - Cleanup (for testing)
    func clearTestGroups(completion: @escaping (Result<Void, Error>) -> Void) {
        // Query all groups owned by current user
        let (userID, _) = self.currentUserIdentifier()
        let predicate = NSPredicate(format: "ownerID == %@", userID)
        let query = CKQuery(recordType: "Group", predicate: predicate)
        
        publicDB.perform(query, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                print("❌ Error fetching test groups: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let records = records, !records.isEmpty else {
                print("✅ No test groups found to delete")
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
            }
            
            print("🗑️ Found \(records.count) test groups to delete")
            
            // Delete each group and its members
            let group = DispatchGroup()
            var deleteErrors: [Error] = []
            
            for record in records {
                group.enter()
                
                // First delete group members
                let memberPredicate = NSPredicate(format: "groupID == %@", record.recordID.recordName)
                let memberQuery = CKQuery(recordType: "GroupMember", predicate: memberPredicate)
                
                self?.publicDB.perform(memberQuery, inZoneWith: nil) { memberRecords, memberError in
                    if let memberError = memberError {
                        print("❌ Error fetching members for group \(record.recordID.recordName): \(memberError.localizedDescription)")
                    } else if let memberRecords = memberRecords {
                        // Delete all members
                        for memberRecord in memberRecords {
                            self?.publicDB.delete(withRecordID: memberRecord.recordID) { _, deleteError in
                                if let deleteError = deleteError {
                                    print("❌ Error deleting member \(memberRecord.recordID.recordName): \(deleteError.localizedDescription)")
                                }
                            }
                        }
                    }
                    
                    // Then delete the group
                    self?.publicDB.delete(withRecordID: record.recordID) { _, deleteError in
                        if let deleteError = deleteError {
                            print("❌ Error deleting group \(record.recordID.recordName): \(deleteError.localizedDescription)")
                            deleteErrors.append(deleteError)
                        } else {
                            print("✅ Deleted group: \(record["name"] as? String ?? "Unknown")")
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                if deleteErrors.isEmpty {
                    print("✅ Successfully cleared all test groups")
                    completion(.success(()))
                } else {
                    print("❌ Some groups failed to delete: \(deleteErrors.count) errors")
                    completion(.failure(deleteErrors.first!))
                }
            }
        }
    }

    // MARK: - Members
    func fetchMembers(groupID: String) {
        let predicate = NSPredicate(format: "groupID == %@", groupID)
        let q = CKQuery(recordType: "GroupMember", predicate: predicate)
        let op = CKQueryOperation(query: q)
        var fetched: [GroupMember] = []

        op.recordMatchedBlock = { _, result in
            if case .success(let rec) = result {
                let id = rec.recordID.recordName
                let userID = rec["userID"] as? String ?? id
                let name = rec["userName"] as? String ?? (rec["name"] as? String) ?? "User"
                let colorHex = rec["colorHex"] as? String
                let color = GroupsManager.colorFromHex(colorHex) ?? .blue
                let joinedAt = (rec["joinedAt"] as? Date) ?? (rec["createdAt"] as? Date) ?? (rec.creationDate ?? Date())
                // Adjust to your GroupMember init as needed:
                fetched.append(GroupMember(id: id, userID: userID, name: name, color: color, joinedAt: joinedAt))
            }
        }
        op.queryResultBlock = { [weak self] res in
            DispatchQueue.main.async {
                switch res {
                case .success:
                    self?.members = fetched.sorted(by: { $0.joinedAt < $1.joinedAt })
                case .failure:
                    self?.members = fetched
                }
            }
        }
        publicDB.add(op)
    }

    // MARK: - Group Name
    func fetchCurrentGroupName() {
        guard let gid = currentGroupID else { return }
        let id = CKRecord.ID(recordName: gid)
        publicDB.fetch(withRecordID: id) { [weak self] rec, _ in
            DispatchQueue.main.async {
                if let rec = rec {
                    let name = rec["name"] as? String
                    if let name, !name.isEmpty {
                        self?.currentGroupName = name
                        self?.persistSelection()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func persistSelection() {
        let d = UserDefaults.standard
        d.setValue(currentGroupID, forKey: kGroupIDKey)
        d.setValue(currentGroupName, forKey: kGroupNameKey)
    }

    /// Ensure a GroupMember exists for (groupID,userID). Creates it if missing.
    private func ensureMembership(groupID: String, userID: String, userName: String, userColor: Color? = nil, completion: @escaping (Bool) -> Void) {
        let predicate = NSPredicate(format: "groupID == %@ AND userID == %@", groupID, userID)
        let q = CKQuery(recordType: "GroupMember", predicate: predicate)
        publicDB.perform(q, inZoneWith: nil) { [weak self] records, _ in
            if let records, !records.isEmpty {
                DispatchQueue.main.async { completion(true) }
                return
            }
            // Create a new membership record
            let rec = CKRecord(recordType: "GroupMember")
            rec["groupID"] = groupID as CKRecordValue
            rec["userID"] = userID as CKRecordValue
            rec["userName"] = userName as CKRecordValue
            rec["name"] = userName as CKRecordValue
            rec["name_lc"] = userName.lowercased() as CKRecordValue
            rec["createdAt"] = Date() as CKRecordValue
            rec["joinedAt"] = Date() as CKRecordValue
            
            // Use provided color or default
            let colorHex = userColor != nil ? userColor!.toHex() : Self.defaultMemberColorHex()
            rec["colorHex"] = colorHex as CKRecordValue

            self?.publicDB.save(rec) { _, _ in
                DispatchQueue.main.async { completion(true) }
            }
        }
    }

    /// Pulls user id/name from our AuthManager/UserDefaults.
    private func currentUserIdentifier() -> (String, String) {
        let d = UserDefaults.standard
        if let appleID = d.string(forKey: "auth.apple.userID"), !appleID.isEmpty {
            let name = d.string(forKey: "auth.displayName") ?? "User"
            return (appleID, name)
        }
        if let recordName = d.string(forKey: "auth.user.recordName"), !recordName.isEmpty {
            let name = d.string(forKey: "auth.displayName") ?? "User"
            return (recordName, name)
        }
        // Fallback (should not happen after login)
        print("⚠️ Warning: No user identifier found, using fallback")
        return (UUID().uuidString, "User")
    }

    private static func generateInviteCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private static func defaultMemberColorHex() -> String {
        return "#8B5E3C"
    }

    private static func colorFromHex(_ hex: String?) -> Color? {
        guard var s = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255.0
            g = Double((v >> 8) & 0xFF) / 255.0
            b = Double(v & 0xFF) / 255.0
            return Color(red: r, green: g, blue: b)
        } else if s.count == 8 {
            let r8 = Double((v >> 24) & 0xFF) / 255.0
            let g8 = Double((v >> 16) & 0xFF) / 255.0
            let b8 = Double((v >> 8)  & 0xFF) / 255.0
            let a8 = Double(v & 0xFF) / 255.0
            return Color(red: r8, green: g8, blue: b8).opacity(a8)
        }
        return nil
    }
    
    // MARK: - Update Member Color
    
    func updateMemberColor(groupID: String, userID: String, newColor: Color) {
        let predicate = NSPredicate(format: "groupID == %@ AND userID == %@", groupID, userID)
        let q = CKQuery(recordType: "GroupMember", predicate: predicate)
        
        publicDB.perform(q, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                print("❌ Error fetching member for color update: \(error.localizedDescription)")
                return
            }
            
            guard let record = records?.first else {
                print("❌ No member record found for color update")
                return
            }
            
            // Update the color
            let colorHex = newColor.toHex()
            record["colorHex"] = colorHex as CKRecordValue
            
            self?.publicDB.save(record) { savedRecord, error in
                if let error = error {
                    print("❌ Error updating member color: \(error.localizedDescription)")
                    return
                }
                
                print("✅ Successfully updated member color to \(colorHex)")
                
                // Update local members array and save to UserDefaults
                DispatchQueue.main.async {
                    if let index = self?.members.firstIndex(where: { $0.userID == userID }) {
                        // Create updated member with new color
                        let updatedMember = GroupMember(
                            id: self?.members[index].id ?? "",
                            userID: userID,
                            name: self?.members[index].name ?? "",
                            color: newColor,
                            joinedAt: self?.members[index].joinedAt ?? Date()
                        )
                        self?.members[index] = updatedMember
                        
                        // Save color to UserDefaults for map pin updates
                        UserDefaults.standard.set(colorHex, forKey: "user.color.hex")
                        
                        // Refresh poop pins to update map colors
                        NotificationCenter.default.post(name: .userColorChanged, object: userID)
                    }
                }
            }
        }
    }
}
