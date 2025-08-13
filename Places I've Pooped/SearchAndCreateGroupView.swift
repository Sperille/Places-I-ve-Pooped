//
//  SearchAndCreateGroupView.swift
//  Places I've Pooped
//

import SwiftUI

struct SearchAndCreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var groupsManager: GroupsManager

    @State private var newGroupName: String = ""
    @State private var isCreating: Bool = false
    @State private var createError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create New Group")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Start a group to share poops with friends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Group Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                        
                        TextField("Enter group name", text: $newGroupName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .font(.system(size: 16))
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
                    .padding(16)
                    .background(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Error Message
                if let createError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 14))
                        Text(createError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer()
                
                // Create Button
                Button {
                    createGroup()
                } label: {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                            Text("Create Group")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isCreating || newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(.systemGray4)
                                : Color.accentColor
                            )
                    )
                    .foregroundColor(.white)
                }
                .disabled(isCreating || newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
    }

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isCreating = true
        createError = nil

        groupsManager.createGroup(name: name) { result in
            isCreating = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                createError = (error as NSError).localizedDescription
            }
        }
    }
}
