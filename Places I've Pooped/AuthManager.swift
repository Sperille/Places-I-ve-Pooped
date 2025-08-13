//
//  AuthManager.swift
//  Places I've Pooped
//

import Foundation
import SwiftUI
import CloudKit
import AuthenticationServices
import UIKit

@MainActor
final class AuthManager: NSObject, ObservableObject {

    // MARK: - Published session state
    @Published var isAuthenticated: Bool = false  // RESTORED: Authentication required for CloudKit
    @Published var currentUserName: String = "User"
    @Published var currentUserEmail: String = ""
    @Published var currentUserRecordID: CKRecord.ID?

    /// Shown after Apple sign-in to let user choose their display name.
    @Published var requiresDisplayNameCapture: Bool = false

    // MARK: - Private
    private var authorizationController: ASAuthorizationController?
    private var revocationObserver: NSObjectProtocol?
    private var pendingAppleUserID: String?

    // Local storage keys
    private let kDisplayNameKey  = "auth.displayName"
    private let kAppleUserIDKey  = "auth.apple.userID"
    private let kUserRecordKey   = "auth.user.recordName"

    // MARK: - Init / Deinit
    override init() {
        super.init()
        revocationObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.signOut() }
        }
    }

    deinit {
        if let obs = revocationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Rehydrate at launch
    func rehydrateOnLaunch() {
        let defaults = UserDefaults.standard

        if let savedName = defaults.string(forKey: kDisplayNameKey), !savedName.isEmpty {
            currentUserName = savedName
        }

        if let appleID = defaults.string(forKey: kAppleUserIDKey), !appleID.isEmpty {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleID) { [weak self] state, _ in
                Task { @MainActor in
                    switch state {
                    case .authorized:
                        await self?.fetchAppleUser(appleID)
                        self?.isAuthenticated = true
                    default:
                        self?.signOut()
                    }
                }
            }
            return
        }

        if let recordName = defaults.string(forKey: kUserRecordKey), !recordName.isEmpty {
            Task { await fetchUserByRecordName(recordName) }
        }
    }

    // MARK: - Apple Sign In
    func startSignInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request  = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        self.authorizationController = controller
    }

    // MARK: - Email/Username Sign Up
    func signUp(email: String, username: String, password: String) async throws {
        let emailLC = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let uname   = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Input validation
        guard !emailLC.isEmpty, !uname.isEmpty, !password.isEmpty else {
            throw NSError(domain: "SignUp", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Please fill all fields."])
        }
        
        // Validate email format
        guard PasswordUtils.validateEmail(email) else {
            throw NSError(domain: "SignUp", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Please enter a valid email address."])
        }
        
        // Validate username
        let usernameValidation = PasswordUtils.validateUsername(uname)
        guard usernameValidation.isValid else {
            throw NSError(domain: "SignUp", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: usernameValidation.errorMessage ?? "Invalid username."])
        }
        
        // Validate password
        let passwordValidation = PasswordUtils.validatePassword(password)
        guard passwordValidation.isValid else {
            throw NSError(domain: "SignUp", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: passwordValidation.errorMessage ?? "Invalid password."])
        }

        // Check if email already exists
        print("🔍 Checking if email already exists: \(emailLC)")
        let emailPredicate = NSPredicate(format: "email_lc == %@", emailLC)
        let emailQuery = CKQuery(recordType: "User", predicate: emailPredicate)
        
        do {
            let existingUsers: [CKRecord] = try await withCheckedThrowingContinuation { cont in
                CKEnv.publicDB.fetch(withQuery: emailQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
                        cont.resume(returning: records)
                    case .failure(let error):
                        print("❌ CloudKit email check error: \(error.localizedDescription)")
                        cont.resume(throwing: error)
                    }
                }
            }
            
            if !existingUsers.isEmpty {
                print("❌ Email already exists: \(emailLC)")
                throw NSError(domain: "SignUp", code: -5,
                              userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists. Please sign in instead."])
            }
            print("✅ Email is available: \(emailLC)")
        } catch let checkError as NSError {
            if checkError.domain == "SignUp" && checkError.code == -5 {
                throw checkError // Re-throw our custom email exists error
            }
            print("❌ Email check failed: \(checkError.localizedDescription)")
            // Continue with signup if we can't check (network issues, etc.)
        }

        // Check if username already exists
        print("🔍 Checking if username already exists: \(uname.lowercased())")
        let usernamePredicate = NSPredicate(format: "username_lc == %@", uname.lowercased())
        let usernameQuery = CKQuery(recordType: "User", predicate: usernamePredicate)
        
        do {
            let existingUsers: [CKRecord] = try await withCheckedThrowingContinuation { cont in
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
                        cont.resume(returning: records)
                    case .failure(let error):
                        print("❌ CloudKit username check error: \(error.localizedDescription)")
                        cont.resume(throwing: error)
                    }
                }
            }
            
            if !existingUsers.isEmpty {
                print("❌ Username already exists: \(uname.lowercased())")
                throw NSError(domain: "SignUp", code: -6,
                              userInfo: [NSLocalizedDescriptionKey: "This username is already taken. Please choose a different one."])
            }
            print("✅ Username is available: \(uname.lowercased())")
        } catch let checkError as NSError {
            if checkError.domain == "SignUp" && checkError.code == -6 {
                throw checkError // Re-throw our custom username exists error
            }
            print("❌ Username check failed: \(checkError.localizedDescription)")
            // Continue with signup if we can't check (network issues, etc.)
        }

        let rec = CKRecord(recordType: "User")
        rec["email"] = email as CKRecordValue
        rec["email_lc"] = emailLC as CKRecordValue
        rec["username"] = uname as CKRecordValue
        rec["username_lc"] = uname.lowercased() as CKRecordValue
        rec["passwordHash"] = PasswordUtils.hashPassword(password) as CKRecordValue
        rec["signInMethod"] = "email" as CKRecordValue

        let saved: CKRecord
        do {
            saved = try await CKEnv.publicDB.save(rec)
        } catch let saveError as CKError {
            print("❌ CloudKit save error: \(saveError.localizedDescription)")
            print("❌ Error code: \(saveError.code.rawValue)")
            
            // Handle quota exceeded specifically
            if saveError.code == .quotaExceeded {
                print("❌ CloudKit quota exceeded - using unsaved record")
                saved = rec
            } else {
                throw saveError
            }
        }

        currentUserRecordID = saved.recordID
        currentUserName = uname
        currentUserEmail = email
        isAuthenticated = true

        let d = UserDefaults.standard
        d.set(uname, forKey: kDisplayNameKey)
        d.set(saved.recordID.recordName, forKey: kUserRecordKey)
        d.removeObject(forKey: kAppleUserIDKey)
    }

    // MARK: - Email/Username Sign In (NEW)
    /// Sign in using email OR username + password.
    func signIn(identifier: String, password: String) async throws {
        let idLC = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !idLC.isEmpty, !password.isEmpty else {
            throw NSError(domain: "SignIn", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter email/username and password."])
        }

        // Try to find user by email first, then by username
        var rec: CKRecord?
        
        // First try email
        let emailPredicate = NSPredicate(format: "email_lc == %@", idLC)
        let emailQuery = CKQuery(recordType: "User", predicate: emailPredicate)
        
        do {
            let emailRecs: [CKRecord] = try await withCheckedThrowingContinuation { cont in
                CKEnv.publicDB.fetch(withQuery: emailQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
                        cont.resume(returning: records)
                    case .failure(let error):
                        print("❌ CloudKit email query error: \(error.localizedDescription)")
                        cont.resume(throwing: error)
                    }
                }
            }
            rec = emailRecs.first
        } catch {
            print("❌ Email query failed, trying username: \(error.localizedDescription)")
        }
        
        // If email didn't work, try username
        if rec == nil {
            let usernamePredicate = NSPredicate(format: "username_lc == %@", idLC)
            let usernameQuery = CKQuery(recordType: "User", predicate: usernamePredicate)
            
            do {
                let usernameRecs: [CKRecord] = try await withCheckedThrowingContinuation { cont in
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
                            cont.resume(returning: records)
                        case .failure(let error):
                            print("❌ CloudKit username query error: \(error.localizedDescription)")
                            cont.resume(throwing: error)
                        }
                    }
                }
                rec = usernameRecs.first
            } catch {
                print("❌ Username query failed: \(error.localizedDescription)")
            }
        }

        guard let rec = rec else {
            throw NSError(domain: "SignIn", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Account not found."])
        }

        // Password verification using hashed password
        let storedHash = (rec["passwordHash"] as? String) ?? ""
        guard PasswordUtils.verifyPassword(password, against: storedHash) else {
            throw NSError(domain: "SignIn", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Incorrect password."])
        }

        // Success → set state
        currentUserRecordID = rec.recordID
        currentUserName = (rec["username"] as? String) ?? "User"
        currentUserEmail = (rec["email"] as? String) ?? ""
        isAuthenticated = true

        let d = UserDefaults.standard
        d.set(currentUserName, forKey: kDisplayNameKey)
        d.set(rec.recordID.recordName, forKey: kUserRecordKey)
        d.removeObject(forKey: kAppleUserIDKey)
    }

    // MARK: - Submit name (if Apple didn’t give it)



    // MARK: - Display Name Capture
    func submitDisplayName(_ displayName: String) async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Update local state
        currentUserName = trimmedName
        requiresDisplayNameCapture = false
        
        // Save to UserDefaults
        UserDefaults.standard.set(trimmedName, forKey: kDisplayNameKey)
        
        // Update CloudKit record if we have one
        if let recordID = currentUserRecordID {
            do {
                let record = try await CKEnv.privateDB.record(for: recordID)
                record["username"] = trimmedName as CKRecordValue
                record["username_lc"] = trimmedName.lowercased() as CKRecordValue
                _ = try await CKEnv.privateDB.save(record)
                print("✅ Successfully updated display name to: \(trimmedName)")
            } catch let saveError as CKError {
                print("❌ CloudKit save error: \(saveError.localizedDescription)")
                print("❌ Error code: \(saveError.code.rawValue)")
                
                if saveError.code == .quotaExceeded {
                    print("❌ CloudKit quota exceeded - display name saved locally only")
                    // The name is already saved locally, so the user can continue
                } else {
                    print("❌ Failed to update display name in CloudKit: \(saveError.localizedDescription)")
                }
            } catch {
                print("❌ Failed to update display name in CloudKit: \(error.localizedDescription)")
            }
        }
        
        pendingAppleUserID = nil
    }
    
    // MARK: - Sign Out
    func signOut() {
        isAuthenticated = false
        currentUserName = "User"
        currentUserEmail = ""
        currentUserRecordID = nil
        requiresDisplayNameCapture = false
        pendingAppleUserID = nil

        let d = UserDefaults.standard
        d.removeObject(forKey: kDisplayNameKey)
        d.removeObject(forKey: kAppleUserIDKey)
        d.removeObject(forKey: kUserRecordKey)
    }

    // MARK: - Helpers
    private func fetchAppleUser(_ appleUserID: String) async {
        let id = CKRecord.ID(recordName: appleUserID)
        do {
            let rec = try await CKEnv.privateDB.record(for: id)
            currentUserRecordID = rec.recordID
            currentUserName = (rec["username"] as? String) ?? "User"
            currentUserEmail = (rec["email"] as? String) ?? ""
            isAuthenticated = true

            UserDefaults.standard.set(currentUserName, forKey: kDisplayNameKey)
            UserDefaults.standard.set(appleUserID, forKey: kAppleUserIDKey)

            // For Apple Sign-In users, always check if they need to set a display name
            if currentUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || currentUserName == "User" {
                pendingAppleUserID = appleUserID
                requiresDisplayNameCapture = true
            }
        } catch {
            signOut()
        }
    }

    private func fetchUserByRecordName(_ recordName: String) async {
        let id = CKRecord.ID(recordName: recordName)
        do {
            let rec = try await CKEnv.privateDB.record(for: id)
            currentUserRecordID = rec.recordID
            currentUserName = (rec["username"] as? String) ?? "User"
            currentUserEmail = (rec["email"] as? String) ?? ""
            isAuthenticated = true

            UserDefaults.standard.set(currentUserName, forKey: kDisplayNameKey)
            UserDefaults.standard.set(recordName, forKey: kUserRecordKey)
        } catch {
            signOut()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let appleUserID = credential.user
        let d = UserDefaults.standard

        // Apple only provides name/email on FIRST auth
        let formatter = PersonNameComponentsFormatter()
        let fullName = formatter.string(from: credential.fullName ?? PersonNameComponents()).trimmingCharacters(in: .whitespacesAndNewlines)
        let email = credential.email ?? ""
        


        Task { @MainActor in
            let recordID = CKRecord.ID(recordName: appleUserID)

            do {
                // Try existing user
                let rec = try await CKEnv.privateDB.record(for: recordID)

                var needsSave = false
                if !fullName.isEmpty, (rec["username"] as? String)?.isEmpty ?? true {
                    rec["username"] = fullName as CKRecordValue
                    rec["username_lc"] = fullName.lowercased() as CKRecordValue
                    needsSave = true
                }
                if !email.isEmpty, (rec["email"] as? String)?.isEmpty ?? true {
                    rec["email"] = email as CKRecordValue
                    rec["email_lc"] = email.lowercased() as CKRecordValue
                    needsSave = true
                }
                let saved: CKRecord
                if needsSave {
                    do {
                        saved = try await CKEnv.publicDB.save(rec)
                    } catch let saveError as CKError {
                        print("❌ CloudKit save error: \(saveError.localizedDescription)")
                        print("❌ Error code: \(saveError.code.rawValue)")
                        
                        // Handle quota exceeded specifically
                        if saveError.code == .quotaExceeded {
                            print("❌ CloudKit quota exceeded - using unsaved record")
                            saved = rec
                        } else {
                            throw saveError
                        }
                    }
                } else {
                    saved = rec
                }

                currentUserRecordID = saved.recordID
                currentUserName = (saved["username"] as? String) ?? "User"
                currentUserEmail = (saved["email"] as? String) ?? email
                isAuthenticated = true
                
                if currentUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || currentUserName == "User" {
                    pendingAppleUserID = appleUserID
                    requiresDisplayNameCapture = true
                }
            } catch {
                // New user → create
                let rec = CKRecord(recordType: "User", recordID: recordID)
                if !email.isEmpty {
                    rec["email"] = email as CKRecordValue
                    rec["email_lc"] = email.lowercased() as CKRecordValue
                }
                if !fullName.isEmpty {
                    rec["username"] = fullName as CKRecordValue
                    rec["username_lc"] = fullName.lowercased() as CKRecordValue
                }
                rec["appleUserID"] = appleUserID as CKRecordValue
                rec["signInMethod"] = "apple" as CKRecordValue

                do {
                    let saved = try await CKEnv.publicDB.save(rec)
                    
                    currentUserRecordID = saved.recordID
                    currentUserName = "User"
                    currentUserEmail = (saved["email"] as? String) ?? ""
                    isAuthenticated = true
                } catch let saveError as CKError {
                    print("❌ CloudKit save error: \(saveError.localizedDescription)")
                    print("❌ Error code: \(saveError.code.rawValue)")
                    
                    // Handle quota exceeded specifically
                    if saveError.code == .quotaExceeded {
                        print("❌ CloudKit quota exceeded - this might be a temporary issue")
                        // Still allow the user to proceed with local authentication
                        currentUserRecordID = recordID
                        currentUserName = "User"
                        currentUserEmail = (rec["email"] as? String) ?? ""
                        isAuthenticated = true
                    } else {
                        // For other errors, throw to be handled by caller
                        throw saveError
                    }
                }
                
                // Always show display name picker for new users
                pendingAppleUserID = appleUserID
                requiresDisplayNameCapture = true
            }

            // Persist locally
            d.set(currentUserName, forKey: kDisplayNameKey)
            d.set(appleUserID, forKey: kAppleUserIDKey)
            d.removeObject(forKey: kUserRecordKey)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign-In failed: \(error.localizedDescription)")
        signOut()
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
