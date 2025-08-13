import SwiftUI
import CloudKit

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager

    @State private var friendUsername = ""
    @State private var isLoading = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Add a Friend")
                .font(.title2)
                .bold()

            TextField("Friend's Username", text: $friendUsername)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Send Friend Request") {
                addFriend()
            }
            .disabled(friendUsername.isEmpty)
            .frame(maxWidth: .infinity)
            .padding()
            .background(friendUsername.isEmpty ? Color.gray : poopColor)
            .foregroundColor(.white)
            .cornerRadius(10)

            if let message = resultMessage {
                Text(message)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    func addFriend() {
        guard let myID = userManager.currentUserID else { return }
        isLoading = true

        let predicate = NSPredicate(format: "username == %@", friendUsername)
        let query = CKQuery(recordType: "User", predicate: predicate)

        CKContainer.default().publicCloudDatabase.perform(query, inZoneWith: nil) { results, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let record = results?.first else {
                    resultMessage = "User not found."
                    return
                }

                let friendID = record.recordID.recordName
                let friendship = CKRecord(recordType: "Friend")
                friendship["userID"] = myID
                friendship["friendUserID"] = friendID

                CKContainer.default().publicCloudDatabase.save(friendship) { _, err in
                    DispatchQueue.main.async {
                        resultMessage = err == nil ? "Friend added!" : "Failed to add."
                    }
                }
            }
        }
    }
}
