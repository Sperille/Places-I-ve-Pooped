//
//  JoinGroupView.swift
//  Places I've Pooped
//

import SwiftUI
import CloudKit

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var groupsManager: GroupsManager

    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var errorText: String?
    @State private var results: [CKRecord] = []
    @State private var selectedColor: Color = .blue
    @State private var showColorPicker = false
    @State private var memberCounts: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search groups by name…", text: $query)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .onSubmit { search() }
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
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button(action: search) {
                        Text("Search").fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                // Color Selection
                HStack {
                    Text("Your Color:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        showColorPicker = true
                    } label: {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                            )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 4)

                if let errorText {
                    Text(errorText)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                List {
                    ForEach(results, id: \.recordID) { rec in
                        let name = rec["name"] as? String ?? "Unnamed Group"
                        let id = rec.recordID.recordName
                        let memberCount = memberCounts[id] ?? 0

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.body.weight(.semibold))
                                Text(memberCount == 0 ? "No members" : "\(memberCount) members").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                groupsManager.joinGroup(groupID: id, name: name, userColor: selectedColor)
                                dismiss()
                            } label: {
                                Text("Join").fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .listStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showColorPicker) {
                NavigationView {
                    VStack(spacing: 20) {
                        Text("Choose Your Color")
                            .font(.headline)
                        
                        ColorPicker("Pin Color", selection: $selectedColor, supportsOpacity: false)
                            .padding()
                        
                        Rectangle()
                            .fill(selectedColor)
                            .frame(height: 60)
                            .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Pick Color")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showColorPicker = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true
        errorText = nil
        results = []

        // Use GroupsManager's Production-safe search
        groupsManager.searchGroups(query: q) { result in
            isSearching = false
            switch result {
            case .success(let records):
                results = records
                if records.isEmpty { 
                    errorText = "No groups found named \"\(q)\"."
                } else {
                    // Fetch member counts for all groups
                    fetchMemberCounts(for: records)
                }
            case .failure(let error):
                errorText = (error as NSError).localizedDescription
            }
        }
    }
    
    private func fetchMemberCounts(for records: [CKRecord]) {
        let groupIDs = records.map { $0.recordID.recordName }
        
        for groupID in groupIDs {
            let predicate = NSPredicate(format: "groupID == %@", groupID)
            let query = CKQuery(recordType: "GroupMember", predicate: predicate)
            
            CKContainer.default().publicCloudDatabase.perform(query, inZoneWith: nil) { records, error in
                DispatchQueue.main.async {
                    if let records = records {
                        memberCounts[groupID] = records.count
                    } else {
                        memberCounts[groupID] = 0
                    }
                }
            }
        }
    }
}
