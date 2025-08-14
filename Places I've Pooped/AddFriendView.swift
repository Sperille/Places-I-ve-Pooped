import SwiftUI
import CloudKit

struct AddFriendView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [FoundUser] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var addingUsername: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search by username", text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .onSubmit { runSearch(term: query) }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button { runSearch(term: query) } label: {
                        Text("Search").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red).font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isSearching {
                    ProgressView("Searching…").frame(maxWidth: .infinity, alignment: .leading)
                }

                List {
                    ForEach(results) { user in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(user.username)").font(.body.weight(.semibold))
                                if let display = user.displayName, !display.isEmpty {
                                    Text(display).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                addFriend(user: user) // byCode under the hood
                            } label: {
                                if addingUsername == user.username { ProgressView() }
                                else { Text("Add").fontWeight(.semibold) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(addingUsername != nil)
                        }
                    }
                }
                .listStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { 
                ToolbarItem(placement: .topBarLeading) { 
                    Button("Close") { 
                        dismiss() 
                    }
                    .foregroundColor(.red)
                } 
            }
        }
    }

    func runSearch(term: String) {
        let q = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true; errorMessage = nil; results = []

        print("🔍 Friend search: Searching for '\(q)'")
        let publicDB = CKEnv.publicDB
        let qLower = q.lowercased()

        // Search by username (case-insensitive) - try multiple approaches
        let predicates = [
            NSPredicate(format: "username BEGINSWITH[cd] %@", q),
            NSPredicate(format: "username_lc BEGINSWITH %@", qLower),
            NSPredicate(format: "username CONTAINS[cd] %@", q)
        ]
        
        let group = DispatchGroup()
        var allHits: [FoundUser] = []
        
        for predicate in predicates {
            group.enter()
            let ckQuery = CKQuery(recordType: "User", predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]
            
            let op = CKQueryOperation(query: ckQuery)
            op.resultsLimit = 20
            
            op.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    let username = (record["username"] as? String) ?? ""
                    let display = record["displayName"] as? String ?? record["email"] as? String
                    let userID = record.recordID.recordName
                    
                    print("🔍 Found user: \(username) (\(userID))")
                    
                    // Don't show yourself in search results
                    guard !username.isEmpty && userID != self.userManager.currentUserID else { 
                        print("🔍 Skipping self or empty username")
                        return 
                    }
                    
                    // Avoid duplicates
                    if !allHits.contains(where: { $0.id == userID }) {
                        allHits.append(FoundUser(id: userID,
                                                username: username,
                                                displayName: display))
                        print("🔍 Added to results: \(username)")
                    }
                }
            }
            
            op.queryResultBlock = { _ in
                group.leave()
            }
            
            publicDB.add(op)
        }
        
        group.notify(queue: .main) {
            self.isSearching = false
            self.results = allHits
            print("🔍 Search complete: Found \(allHits.count) users")
            if allHits.isEmpty {
                self.errorMessage = "No users found matching '\(q)'"
            }
        }
        

    }

    private func addFriend(user: FoundUser) {
        print("👥 Adding friend: \(user.username) (\(user.id))")
        addingUsername = user.username
        userManager.addFriend(byCode: user.id) { success in
            DispatchQueue.main.async {
                if success { 
                    print("✅ Successfully added friend: \(user.username)")
                    dismiss() 
                }
                else {
                    print("❌ Failed to add friend: \(user.username)")
                    self.errorMessage = "Couldn’t add @\(user.username). They may already be your friend."
                    self.addingUsername = nil
                }
            }
        }
    }
}

private struct FoundUser: Identifiable {
    let id: String
    let username: String
    let displayName: String?
}
