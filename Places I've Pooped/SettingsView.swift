//
//  SettingsView.swift
//  Places I've Pooped
//

import SwiftUI
import CloudKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @StateObject private var notificationManager = NotificationManager()
    
    @State private var newUsername = ""
    @State private var showChangeUsername = false
    @State private var isUpdatingUsername = false
    @State private var usernameError: String?
    
    var body: some View {
        NavigationStack {
            List {
                // App Settings Section
                Section("App Settings") {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                        Text("Dark Mode")
                        Spacer()
                        Toggle("", isOn: $isDarkMode)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications")
                                .font(.body)
                            Text("Group & Friend Poops")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $notificationManager.isNotificationsEnabled)
                            .onChange(of: notificationManager.isNotificationsEnabled) { _, newValue in
                                if newValue {
                                    Task {
                                        await notificationManager.requestNotificationPermission()
                                    }
                                } else {
                                    notificationManager.disableNotifications()
                                }
                            }
                    }
                }
                
                // Account Settings Section
                Section("Account") {
                    Button {
                        newUsername = auth.currentUserName
                        showChangeUsername = true
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text("Change Username")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(isUpdatingUsername)
                }
                
                // Legal Section
                Section("Legal") {
                    Button {
                        if let url = URL(string: "https://your-privacy-policy-url.com") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.green)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        if let url = URL(string: "https://your-terms-of-service-url.com") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.orange)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // App Info Section
                Section("App Info") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showChangeUsername) {
            ChangeUsernameSheet(
                newUsername: $newUsername,
                isUpdating: $isUpdatingUsername,
                error: $usernameError,
                onUpdate: updateUsername
            )
        }
    }
    
    private func updateUsername() {
        guard !newUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            usernameError = "Username cannot be empty"
            return
        }
        
        let trimmedUsername = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if username is already taken
        let predicate = NSPredicate(format: "name_lc == %@", trimmedUsername.lowercased())
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        CKEnv.publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (results, _)):
                    if !results.isEmpty {
                        usernameError = "Username is already taken"
                        return
                    }
                    
                    // Username is available, proceed with update
                    updateUsernameInCloudKit(trimmedUsername)
                    
                case .failure(let error):
                    print("❌ Error checking username availability: \(error.localizedDescription)")
                    usernameError = "Failed to check username availability"
                }
            }
        }
    }
    
    private func updateUsernameInCloudKit(_ newUsername: String) {
        isUpdatingUsername = true
        usernameError = nil
        
        // Update local auth manager
        auth.currentUserName = newUsername
        UserDefaults.standard.set(newUsername, forKey: "auth.user.name")
        
        // Update CloudKit record
        guard let userID = auth.currentUserRecordID?.recordName else {
            isUpdatingUsername = false
            usernameError = "User record not found"
            return
        }
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        CKEnv.publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (results, _)):
                    if let record = results.first?.1 {
                        switch record {
                        case .success(let userRecord):
                            userRecord["name"] = newUsername as CKRecordValue
                            userRecord["name_lc"] = newUsername.lowercased() as CKRecordValue
                            
                            CKEnv.publicDB.save(userRecord) { _, error in
                                DispatchQueue.main.async {
                                    isUpdatingUsername = false
                                    if let error = error {
                                        print("❌ Error updating username in CloudKit: \(error.localizedDescription)")
                                        usernameError = "Failed to update username"
                                    } else {
                                        print("✅ Username updated successfully in CloudKit")
                                        showChangeUsername = false
                                    }
                                }
                            }
                            
                        case .failure(let error):
                            isUpdatingUsername = false
                            print("❌ Error accessing user record: \(error.localizedDescription)")
                            usernameError = "Failed to access user record"
                        }
                    } else {
                        isUpdatingUsername = false
                        usernameError = "User record not found"
                    }
                    
                case .failure(let error):
                    isUpdatingUsername = false
                    print("❌ Error fetching user record: \(error.localizedDescription)")
                    usernameError = "Failed to fetch user record"
                }
            }
        }
    }
}

struct ChangeUsernameSheet: View {
    @Binding var newUsername: String
    @Binding var isUpdating: Bool
    @Binding var error: String?
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Username")
                        .font(.headline)
                    
                    TextField("Enter new username", text: $newUsername)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Change Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        onUpdate()
                    }
                    .disabled(isUpdating || newUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
