import SwiftUI
import CloudKit

struct SearchAndCreateGroupView: View {
    @EnvironmentObject var groupsManager: GroupsManager
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var searchResults: [CKRecord] = []
    @State private var groupNameToCreate: String = ""
    @State private var isCreating = false
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 🔍 Search Field
                HStack {
                    TextField("Search Groups...", text: $searchText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    Button("Search") {
                        searchGroups()
                    }
                    .buttonStyle(.borderedProminent)
                }

                // 🔍 Search Results
                if isSearching {
                    ProgressView("Searching...")
                } else {
                    List(searchResults, id: \.recordID) { record in
                        Button(action: {
                            let groupID = record.recordID.recordName
                            groupsManager.joinGroup(groupID: groupID)
                            dismiss()
                        }) {
                            Text(record["name"] as? String ?? "Unknown Group")
                        }
                    }
                }

                Divider()

                // ➕ Create Group
                VStack(alignment: .leading) {
                    Text("Create New Group")
                        .font(.headline)

                    TextField("Group Name", text: $groupNameToCreate)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    Button("Create Group") {
                        createGroup()
                    }
                    .disabled(groupNameToCreate.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(groupNameToCreate.isEmpty ? Color.gray : poopColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)

                    if isCreating {
                        ProgressView("Creating...")
                    }
                }
                .padding(.top)

                Spacer()
            }
            .padding()
            .navigationTitle("Join or Create Group")
        }
    }

    // MARK: - Search Groups
    func searchGroups() {
        isSearching = true
        let predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        let query = CKQuery(recordType: "Group", predicate: predicate)

        CKContainer.default().publicCloudDatabase.perform(query, inZoneWith: nil) { results, error in
            DispatchQueue.main.async {
                self.searchResults = results ?? []
                self.isSearching = false
            }
        }
    }

    // MARK: - Create Group
    func createGroup() {
        isCreating = true
        let groupRecord = CKRecord(recordType: "Group")
        groupRecord["name"] = groupNameToCreate

        CKContainer.default().publicCloudDatabase.save(groupRecord) { savedRecord, error in
            guard let savedRecord = savedRecord, error == nil else {
                print("❌ Error creating group: \(error?.localizedDescription ?? "Unknown")")
                DispatchQueue.main.async { self.isCreating = false }
                return
            }

            let groupID = savedRecord.recordID.recordName
            DispatchQueue.main.async {
                groupsManager.joinGroup(groupID: groupID)
                self.addUserToGroup(groupID: groupID)
                self.isCreating = false
                dismiss()
            }
        }
    }

    // MARK: - Save User Membership
    func addUserToGroup(groupID: String) {
        guard let userID = userManager.currentUserID,
              let name = userManager.currentUserName else { return }

        let record = CKRecord(recordType: "GroupMember")
        record["name"] = name
        record["userID"] = userID
        record["groupID"] = groupID
        record["joinedAt"] = Date()
        record["colorHex"] = "#6B4F3B" // Default until chosen

        CKContainer.default().privateCloudDatabase.save(record) { _, err in
            if let err = err {
                print("❌ Failed to save group member: \(err.localizedDescription)")
            } else {
                print("✅ User joined group")
                groupsManager.fetchMembers(groupID: groupID)
            }
        }
    }
}
