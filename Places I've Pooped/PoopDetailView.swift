//
//  PoopDetailView.swift
//  Places I've Pooped
//

//
//  PoopDetailView.swift
//  Places I've Pooped
//

import SwiftUI
import MapKit
import CloudKit

struct PoopDetailView: View {
    let poop: PoopPin

    // No PoopManager dependency anymore
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var groupsManager: GroupsManager
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var newCommentText: String = ""
    @State private var comments: [ScopedPoopComment] = []   // scoped to this poop only

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(poop.userName)
                        .font(.headline)
                    if !poop.locationDescription.isEmpty {
                        Text(poop.locationDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(poop.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Photo
                if let url = poop.photoURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack { Rectangle().opacity(0.05); ProgressView() }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure: EmptyView()
                        @unknown default: EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                }

                // Initial feedback (matching LogPoopView order)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(poop.userName)'s Rating").font(.headline)
                    VStack(spacing: 8) {
                        StarRow(title: "Toilet Paper", value: poop.tpRating)
                        StarRow(title: "Cleanliness", value: poop.cleanliness)
                        StarRow(title: "Privacy", value: poop.privacy)
                        StarRow(title: "Plumbing", value: poop.plumbing)
                        StarRow(title: "Overall Vibes", value: poop.overallVibes)
                    }
                }

                // Original comment
                if !poop.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(poop.userName)'s Comment").font(.headline)
                        Text(poop.comment).font(.body)
                    }
                }

                // Comments (scoped)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comments").font(.headline)

                    if comments.isEmpty {
                        Text("No comments yet. Be the first!")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(comments) { c in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(c.userName).font(.subheadline).bold()
                                    Spacer()
                                    Text(c.createdAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(c.text).font(.body)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Add a comment (modernized)
                    VStack(spacing: 12) {
                        TextField("Add a comment…", text: $newCommentText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.brown.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.brown.opacity(0.3), lineWidth: 1)
                            )
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }
                                }
                            }
                        
                        Button("Post Comment") { addCommentTapped() }
                            .buttonStyle(.borderedProminent)
                            .tint(.brown)
                            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Poop Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadComments() }
    }

    // MARK: - Actions

    private func addCommentTapped() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newCommentText = ""

        let uid = userManager.currentUserID ?? "unknown"
        let name = getProperUserName()

        // Optimistic local insert (scoped)
        let local = ScopedPoopComment(
            id: UUID().uuidString,
            poopID: poop.id,
            userID: uid,
            userName: name,
            text: trimmed,
            createdAt: Date()
        )
        comments.append(local)

        // Save to CloudKit with better optimistic handling
        saveCommentToCloudKit(poopID: poop.id, uid: uid, name: name, text: trimmed) { success in
            if success {
                // Only refresh after a short delay to ensure CloudKit has processed it
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    Task { await loadComments() }
                }
            } else {
                // If save failed, remove the optimistic comment
                DispatchQueue.main.async {
                    if let index = self.comments.firstIndex(where: { $0.id == local.id }) {
                        self.comments.remove(at: index)
                    }
                }
            }
        }
    }

    @MainActor
    private func loadComments() async {
        fetchCommentsFromCloudKit(poopID: poop.id) { scoped in
            self.comments = scoped
        }
    }
    
    // MARK: - Helper Functions
    
    private func getProperUserName() -> String {
        // Try to get name from multiple sources
        let authName = auth.currentUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultsName = UserDefaults.standard.string(forKey: "auth.displayName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use auth name if available, otherwise try UserDefaults, otherwise fallback
        return authName.isEmpty ? (defaultsName ?? "User") : authName
    }
}

// MARK: - Scoped model

private struct ScopedPoopComment: Identifiable, Equatable {
    let id: String
    let poopID: String
    let userID: String
    let userName: String
    let text: String
    let createdAt: Date
}

// MARK: - CloudKit helpers (scoped to this view)

private func fetchCommentsFromCloudKit(poopID: String, completion: @escaping ([ScopedPoopComment]) -> Void) {
    let predicate = NSPredicate(format: "poopID == %@", poopID)
    let query = CKQuery(recordType: "PoopComment", predicate: predicate)
    query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

    let dbs: [CKDatabase] = [CKEnv.publicDB, CKEnv.privateDB]
    let group = DispatchGroup()
    var bucket: [ScopedPoopComment] = []
    let lock = NSLock()

    func map(_ r: CKRecord) -> ScopedPoopComment? {
        let id = r.recordID.recordName
        let userID = (r["userID"] as? String) ?? "unknown"
        let userName = (r["userName"] as? String) ?? "User"
        let text = (r["text"] as? String) ?? ""
        let createdAt = (r["createdAt"] as? Date) ?? (r.creationDate ?? Date())
        return ScopedPoopComment(id: id, poopID: poopID, userID: userID, userName: userName, text: text, createdAt: createdAt)
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
        let unique = Dictionary(bucket.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let sorted = unique.values.sorted(by: { $0.createdAt < $1.createdAt })
        completion(sorted)
    }
}

private func saveCommentToCloudKit(poopID: String,
                                   uid: String,
                                   name: String,
                                   text: String,
                                   completion: @escaping (Bool) -> Void) {
    let rec = CKRecord(recordType: "PoopComment")
    rec["poopID"] = poopID as CKRecordValue
    rec["userID"] = uid as CKRecordValue
    rec["userName"] = name as CKRecordValue
    rec["text"] = text as CKRecordValue
    rec["createdAt"] = Date() as CKRecordValue

    // Prefer public DB so others in group can see it
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

// MARK: - Stars row

private struct StarRow: View {
    let title: String
    let value: Int // 0...5

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < max(0, min(5, value)) ? "star.fill" : "star")
                        .foregroundColor(i < max(0, min(5, value)) ? .yellow : .gray)
                        .imageScale(.small)
                }
            }
        }
    }
}
