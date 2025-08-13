//
//  LoginView.swift
//  Places I've Pooped
//
//

import SwiftUI
import AuthenticationServices

// MARK: - LoginView
struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager

    // Which sheet is open?
    private enum ActiveSheet: Identifiable { case emailSignIn, createAccount
        var id: Int { hashValue }
    }
    @State private var activeSheet: ActiveSheet?

    // Error surfaced at top (from either flow)
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo
                VStack(spacing: 8) {
                    Text("Places I've Pooped")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("💩")
                        .font(.system(size: 48))
                }
                .padding(.top, 8)

                // Primary actions card
                VStack(spacing: 14) {
                    // Apple
                    AppleSignInButton {
                        auth.startSignInWithApple()
                    }
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Or divider
                    HStack {
                        Rectangle().frame(height: 1).opacity(0.12)
                        Text("or").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Rectangle().frame(height: 1).opacity(0.12)
                    }

                    // Email sign in
                    Button {
                        activeSheet = .emailSignIn
                    } label: {
                        Text("Sign in with Email")
                            .frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))

                // Create account
                Button {
                    activeSheet = .createAccount
                } label: {
                    Text("Create Account")
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(poopColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 4)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .emailSignIn:
                    EmailSignInSheet { identifier, password in
                        Task {
                            do {
                                try await auth.signIn(identifier: identifier, password: password)
                            } catch {
                                await MainActor.run { self.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                case .createAccount:
                    CreateAccountSheet { email, username, password in
                        Task {
                            do {
                                try await auth.signUp(email: email, username: username, password: password)
                            } catch {
                                await MainActor.run { self.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sheets
private struct EmailSignInSheet: View {
    var onSubmit: (_ identifier: String, _ password: String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var identifier = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    TextField("Email or Username", text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .padding(12)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if let localError {
                    Text(localError).font(.footnote).foregroundStyle(.red)
                }

                Button {
                    isBusy = true
                    onSubmit(identifier, password)
                    // let parent surface errors; auto dismiss when auth flips
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isBusy = false; dismiss() }
                } label: {
                    Text(isBusy ? "Signing In…" : "Sign In")
                        .frame(maxWidth: .infinity).frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || identifier.isEmpty || password.isEmpty)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Sign in with Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct CreateAccountSheet: View {
    var onSubmit: (_ email: String, _ username: String, _ password: String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))

                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .padding(12)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if let localError {
                    Text(localError).font(.footnote).foregroundStyle(.red)
                }

                Button {
                    isBusy = true
                    onSubmit(email, username, password)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isBusy = false; dismiss() }
                } label: {
                    Text(isBusy ? "Creating…" : "Create Account")
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(poopColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .disabled(isBusy || email.isEmpty || username.isEmpty || password.isEmpty)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
