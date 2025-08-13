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
    @AppStorage("overrideSystemAppearance") private var overrideSystemAppearance: Bool = false
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.purple)
                            Text("Override System Appearance")
                            Spacer()
                            Toggle("", isOn: $overrideSystemAppearance)
                        }
                        
                        if overrideSystemAppearance {
                            HStack {
                                Image(systemName: "moon.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Dark Mode")
                                Spacer()
                                Toggle("", isOn: $isDarkMode)
                            }
                            .padding(.leading, 20)
                        }
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
                            Image(systemName: "arrow.up.right.square")
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
                            Image(systemName: "arrow.up.right.square")
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
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Change Username", isPresented: $showChangeUsername) {
            TextField("New username", text: $newUsername)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            
            Button("Cancel", role: .cancel) {
                newUsername = ""
                usernameError = nil
            }
            
            Button("Update") {
                updateUsername()
            }
            .disabled(newUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            if let error = usernameError {
                Text(error)
            } else {
                Text("Enter a new username for your account.")
            }
        }
    }
    
    private func updateUsername() {
        let trimmedUsername = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }
        
        isUpdatingUsername = true
        usernameError = nil
        
        // Validate username
        let usernameValidation = PasswordUtils.validateUsername(trimmedUsername)
        guard usernameValidation.isValid else {
            usernameError = usernameValidation.errorMessage ?? "Invalid username"
            isUpdatingUsername = false
            return
        }
        
        // Check if username already exists
        let usernamePredicate = NSPredicate(format: "username_lc == %@", trimmedUsername.lowercased())
        let usernameQuery = CKQuery(recordType: "User", predicate: usernamePredicate)
        
        CKEnv.publicDB.fetch(withQuery: usernameQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
                DispatchQueue.main.async {
                    // Check if username is taken by someone else
                    if !records.isEmpty {
                        let existingUser = records.first
                        let existingUserID = existingUser?["userID"] as? String ?? existingUser?.recordID.recordName
                        
                        // Allow if it's the same user
                        if existingUserID != auth.currentUserRecordID?.recordName {
                            usernameError = "This username is already taken. Please choose a different one."
                            isUpdatingUsername = false
                            return
                        }
                    }
                    
                    // Update the username
                    updateUsernameInCloudKit(trimmedUsername)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    usernameError = "Network error: \(error.localizedDescription)"
                    isUpdatingUsername = false
                }
            }
        }
    }
    
    func updateUsernameInCloudKit(_ newUsername: String) {
        guard let userRecordID = auth.currentUserRecordID else {
            usernameError = "User record not found"
            isUpdatingUsername = false
            return
        }
        
        let recordID = CKRecord.ID(recordName: userRecordID.recordName)
        CKEnv.publicDB.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                if let error = error {
                    usernameError = "Failed to fetch user record: \(error.localizedDescription)"
                    isUpdatingUsername = false
                    return
                }
                
                guard let record = record else {
                    usernameError = "User record not found"
                    isUpdatingUsername = false
                    return
                }
                
                // Update the username fields
                record["username"] = newUsername as CKRecordValue
                record["username_lc"] = newUsername.lowercased() as CKRecordValue
                
                CKEnv.publicDB.save(record) { savedRecord, saveError in
                    DispatchQueue.main.async {
                        if let saveError = saveError {
                            usernameError = "Failed to update username: \(saveError.localizedDescription)"
                            isUpdatingUsername = false
                            return
                        }
                        
                        // Update local state
                        auth.currentUserName = newUsername
                        UserDefaults.standard.set(newUsername, forKey: "auth.displayName")
                        
                        // Close the alert and reset state
                        showChangeUsername = false
                        isUpdatingUsername = false
                        self.newUsername = ""
                        usernameError = nil
                        
                        print("✅ Username updated successfully to: \(newUsername)")
                    }
                }
            }
        }
    }
}
