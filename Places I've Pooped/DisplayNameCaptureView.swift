//
//  DisplayNameCaptureView.swift
//  Places I've Pooped
//

import SwiftUI

struct DisplayNameCaptureView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var displayName: String = ""
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {

                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Choose Your Display Name")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This is how you'll appear to other users in the app")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .onSubmit {
                            submitName()
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                }
                .padding(.horizontal, 20)
                
                // Submit button
                Button(action: submitName) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isSubmitting ? "Setting Name..." : "Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private func submitName() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isSubmitting = true
        
        Task { @MainActor in
            await auth.submitDisplayName(trimmedName)
            isSubmitting = false
        }
    }
}

#Preview {
    DisplayNameCaptureView()
        .environmentObject(AuthManager())
}
