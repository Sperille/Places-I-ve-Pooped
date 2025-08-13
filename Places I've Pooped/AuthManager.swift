import SwiftUI
import CloudKit
import CryptoKit
import AuthenticationServices

final class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserRecordID: CKRecord.ID?
    @Published var currentUserName: String?
    @Published var currentUserEmail: String?

    // MARK: - Public API

    func signUp(email: String, username: String, password: String) async throws {
        let hash = Self.sha256(password)
        let record = CKRecord(recordType: "User")
        record["email"] = email as CKRecordValue
        record["username"] = username as CKRecordValue
        record["passwordHash"] = hash as CKRecordValue
        // Optional: store lowercase fields for case-insensitive lookup
        record["email_lc"] = email.lowercased() as CKRecordValue
        record["username_lc"] = username.lowercased() as CKRecordValue

        let saved = try await CKContainer.default().publicCloudDatabase.save(record)
        await setSession(with: saved)
    }

    /// identifier = email or username, case-insensitive
    func signIn(identifier: String, password: String) async throws {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = Self.sha256(password)

        // Try email first, then username.
        if let user = try await fetchUser(where: NSPredicate(format: "email_lc == %@", id)) ?? fetchUser(where: NSPredicate(format: "username_lc == %@", id)) {
            guard let stored = user["passwordHash"] as? String, stored == hash else {
                throw AuthError.invalidCredentials
            }
            await setSession(with: user)
        } else {
            throw AuthError.userNotFound
        }
    }

    // MARK: - Sign in with Apple

    func startSignInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signOut() {
        isAuthenticated = false
        currentUserRecordID = nil
        currentUserName = nil
        currentUserEmail = nil
    }

    // MARK: - Helpers

    private func fetchUser(where predicate: NSPredicate) async throws -> CKRecord? {
        let q = CKQuery(recordType: "User", predicate: predicate)
        let (match, _) = try await CKContainer.default().publicCloudDatabase.records(matching: q, desiredKeys: nil)
        return match.values.compactMap { result in
            if case .success(let rec) = result { return rec } else { return nil }
        }.first
    }

    @MainActor
    private func setSession(with record: CKRecord) {
        currentUserRecordID = record.recordID
        currentUserName = (record["username"] as? String) ?? (record["email"] as? String) ?? "User"
        currentUserEmail = record["email"] as? String
        isAuthenticated = true
    }

    static func sha256(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    enum AuthError: LocalizedError {
        case invalidCredentials, userNotFound
        var errorDescription: String? {
            switch self {
            case .invalidCredentials: return "Invalid email/username or password."
            case .userNotFound:       return "No account found for that identifier."
            }
        }
    }
}

// MARK: - Sign in with Apple handlers
extension AuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Best-effort: use the first window
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        Task {
            do {
                let userID = credential.user                      // Stable Apple ID for your app
                let email = credential.email                      // Only present the first time
                let fullName = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                let username = fullName.isEmpty ? "User" : fullName

                // Find existing by stored appleUserID, or create.
                let pred = NSPredicate(format: "appleUserID == %@", userID)
                if let existing = try await fetchUser(where: pred) {
                    await setSession(with: existing)
                } else {
                    let rec = CKRecord(recordType: "User")
                    rec["appleUserID"] = userID as CKRecordValue
                    if let email { rec["email"] = email as CKRecordValue; rec["email_lc"] = email.lowercased() as CKRecordValue }
                    rec["username"] = username as CKRecordValue
                    rec["username_lc"] = username.lowercased() as CKRecordValue
                    // No passwordHash for Apple-auth accounts

                    let saved = try await CKContainer.default().publicCloudDatabase.save(rec)
                    await setSession(with: saved)
                }
            } catch {
                print("SIWA error: \(error.localizedDescription)")
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign-In failed: \(error.localizedDescription)")
    }
}
