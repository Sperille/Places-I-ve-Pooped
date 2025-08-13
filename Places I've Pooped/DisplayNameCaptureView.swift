//
//  DisplayNameCaptureView.swift
//  Places I've Pooped
//

import SwiftUI

struct DisplayNameCaptureView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Choose a display name")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("We didn’t receive your name from Apple. Pick a name to show on your posts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                Button {
                    Task {
                        await auth.submitDisplayName(name)
                        dismiss()
                    }
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Pre-fill if auth has something other than default
            let n = auth.currentUserName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty && n != "User" { self.name = n }
        }
    }
}
