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

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Search groups by name…", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { search() }

                    Button {
                        search()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .padding(8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }

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

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.body.weight(.semibold))
                                Text(id).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                groupsManager.joinGroup(groupID: id, name: name)
                                dismiss()
                            } label: {
                                Text("Join")
                                    .fontWeight(.semibold)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
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

        groupsManager.searchGroups(matching: q) { result in
            isSearching = false
            switch result {
            case .success(let records):
                results = records
                if records.isEmpty {
                    errorText = "No groups found named “\(q)”."
                }
            case .failure(let error):
                errorText = (error as NSError).localizedDescription
            }
        }
    }
}
