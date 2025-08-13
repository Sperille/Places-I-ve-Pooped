//
//  SessionManager.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/3/25.
//

import Foundation
import AuthenticationServices
import Combine

class SessionManager: NSObject, ObservableObject {
    @Published var isLoggedIn = false
    @Published var userIdentifier: String?

    override init() {
        super.init()
        if let storedID = UserDefaults.standard.string(forKey: "appleUserID") {
            userIdentifier = storedID
            isLoggedIn = true
        }
    }

    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signOut() {
        self.userIdentifier = nil
        self.isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "appleUserID")
    }
}

extension SessionManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = appleIDCredential.user
            self.userIdentifier = userID
            self.isLoggedIn = true
            UserDefaults.standard.set(userID, forKey: "appleUserID")
            UserDefaults.standard.synchronize()
            print("✅ Signed in with Apple ID: \(userID)")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In failed: \(error.localizedDescription)")
    }
}

extension SessionManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}
