//
//  AppleSignInButton.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/8/25.
//


import SwiftUI
import AuthenticationServices

struct AppleSignInButton: UIViewRepresentable {
    var action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let v = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        v.cornerRadius = 12
        v.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return v
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}
