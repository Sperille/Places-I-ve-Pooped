//
//  UserManager.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/6/25.
//

import Foundation
import CloudKit
import SwiftUI
import AuthenticationServices

struct Friend: Identifiable {
    var id: String
    var name: String
}

class UserManager: ObservableObject {
    @Published var currentUserID: String?
    @Published var currentUserName: String?
    @Published var friends: [Friend] = []
    
    init() {
        // Simulator bypass for testing
        #if targetEnvironment(simulator)
        print("🖥️ Simulator: Setting up test user data")
        self.currentUserID = "simulator-user"
        self.currentUserName = "Simulator User"
        self.friends = [
            Friend(id: "virginia-friend", name: "Virginia Friend")
        ]
        return
        #endif
    }

    // MARK: - Login with email/password
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        let predicate = NSPredicate(format: "email == %@ AND password == %@", email, password)
        let query = CKQuery(recordType: "User", predicate: predicate)

        CKEnv.publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            DispatchQueue.main.async {
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
                    guard let user = records.first else {
                        completion(false, "Invalid credentials")
                        return
                    }
                    
                    self.currentUserID = user.recordID.recordName
                    self.currentUserName = user["username"] as? String
                    completion(true, nil)
                case .failure:
                    completion(false, "Network error")
                }
            }
        }
    }

    // MARK: - Register
    func register(email: String, password: String, username: String, completion: @escaping (Bool, String?) -> Void) {
        // Check if email already exists
        print("🔍 UserManager: Checking if email already exists: \(email.lowercased())")
        let emailPredicate = NSPredicate(format: "email == %@", email.lowercased())
        let emailQuery = CKQuery(recordType: "User", predicate: emailPredicate)
        
        CKEnv.publicDB.fetch(withQuery: emailQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { [weak self] result in
            switch result {
            case .success(let queryResult):
                let emailRecords = queryResult.matchResults.compactMap { _, recordResult in
                    switch recordResult {
                    case .success(let record):
                        return record
                    case .failure:
                        return nil
                    }
                }
                
                if !emailRecords.isEmpty {
                    print("❌ UserManager: Email already exists: \(email.lowercased())")
                    DispatchQueue.main.async {
                        completion(false, "An account with this email already exists. Please sign in instead.")
                    }
                    return
                }
                print("✅ UserManager: Email is available: \(email.lowercased())")
            case .failure(let emailError):
                DispatchQueue.main.async {
                    completion(false, "Network error checking email: \(emailError.localizedDescription)")
                }
                return
            }
            
            // Check if username already exists
            print("🔍 UserManager: Checking if username already exists: \(username.lowercased())")
            let usernamePredicate = NSPredicate(format: "username == %@", username.lowercased())
            let usernameQuery = CKQuery(recordType: "User", predicate: usernamePredicate)
            
            CKEnv.publicDB.fetch(withQuery: usernameQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { [weak self] result in
                switch result {
                case .success(let queryResult):
                    let usernameRecords = queryResult.matchResults.compactMap { _, recordResult in
                        switch recordResult {
                        case .success(let record):
                            return record
                        case .failure:
                            return nil
                        }
                    }
                    
                    if !usernameRecords.isEmpty {
                        print("❌ UserManager: Username already exists: \(username.lowercased())")
                        DispatchQueue.main.async {
                            completion(false, "This username is already taken. Please choose a different one.")
                        }
                        return
                    }
                    print("✅ UserManager: Username is available: \(username.lowercased())")
                case .failure(let usernameError):
                    DispatchQueue.main.async {
                        completion(false, "Network error checking username: \(usernameError.localizedDescription)")
                    }
                    return
                }
                
                // Create the user record
                let record = CKRecord(recordType: "User")
                record["email"] = email
                record["email_lc"] = email.lowercased()
                record["username"] = username
                record["username_lc"] = username.lowercased()
                record["password"] = password
                record["signInMethod"] = "email"

                CKEnv.publicDB.save(record) { saved, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(false, error.localizedDescription)
                        } else {
                            self?.currentUserID = saved?.recordID.recordName
                            self?.currentUserName = username
                            completion(true, nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Add Friend
    func addFriend(byCode code: String, completion: @escaping (Bool) -> Void) {
        // Prevent adding yourself as a friend
        guard code != currentUserID else {
            print("❌ Cannot add yourself as a friend")
            completion(false)
            return
        }
        
        let recordID = CKRecord.ID(recordName: code)
        CKEnv.publicDB.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                guard let record = record else {
                    completion(false)
                    return
                }

                let friend = Friend(id: record.recordID.recordName, name: record["username"] as? String ?? "Unknown")
                if !self.friends.contains(where: { $0.id == friend.id }) {
                    self.friends.append(friend)
                }

                completion(true)
            }
        }
    }
    
    // MARK: - Add Friend by UserID and Name
    func addFriend(userID: String, name: String) {
        // Prevent adding yourself as a friend
        guard userID != currentUserID else {
            print("❌ Cannot add yourself as a friend")
            return
        }
        
        let friend = Friend(id: userID, name: name)
        if !self.friends.contains(where: { $0.id == friend.id }) {
            self.friends.append(friend)
            print("✅ Added friend: \(name) (\(userID))")
        } else {
            print("ℹ️ Friend already exists: \(name) (\(userID))")
        }
    }

    // MARK: - Apple Sign-In
    func handleAppleSignIn(credential: ASAuthorizationCredential) {
        if let appleIDCredential = credential as? ASAuthorizationAppleIDCredential {
            let userID = appleIDCredential.user
            let email = appleIDCredential.email ?? "unknown@email.com"
            let username = appleIDCredential.fullName?.givenName ?? "User"

            currentUserID = userID
            currentUserName = username

            let recordID = CKRecord.ID(recordName: userID)
            CKEnv.publicDB.fetch(withRecordID: recordID) { existing, error in
                if existing != nil {
                    print("✅ Apple ID already exists")
                } else {
                    let record = CKRecord(recordType: "User", recordID: recordID)
                    record["email"] = email
                    record["username"] = username
                    record["password"] = "apple" // placeholder
                    record["signInMethod"] = "apple"

                    CKEnv.publicDB.save(record) { _, error in
                        if let error = error {
                            print("❌ Failed to save Apple user: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
