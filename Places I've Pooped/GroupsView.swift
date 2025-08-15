//
//  GroupsView.swift
//  Places I've Pooped
//

import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var groupsManager: GroupsManager
    @EnvironmentObject private var menuState: MenuState
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var poopManager: PoopManager
    @EnvironmentObject private var userManager: UserManager

    @State private var showJoin = false
    @State private var showCreate = false
    @State private var showLeaveConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showColorPicker = false
    @State private var selectedColor: Color = .blue
    @State private var isDeleting = false
    
    // MARK: - Simple Group View
    private struct SimpleGroupView: View {
        @EnvironmentObject private var groupsManager: GroupsManager
        @EnvironmentObject private var userManager: UserManager
        @EnvironmentObject private var poopManager: PoopManager
        @EnvironmentObject private var auth: AuthManager
        
        @Binding var selectedColor: Color
        @Binding var showColorPicker: Bool
        @Binding var showLeaveConfirm: Bool
        @Binding var showDeleteConfirm: Bool
        @Binding var isDeleting: Bool
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Group Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Info").font(.headline)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(groupsManager.currentGroupName ?? "Your Group")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Current user's color editing section
                    if let userID = auth.currentUserRecordID?.recordName,
                       let currentMember = groupsManager.members.first(where: { $0.userID == userID }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Color").font(.headline)
                            HStack {
                                Circle()
                                    .fill(currentMember.color)
                                    .frame(width: 24, height: 24)
                                
                                Text("Map Pin Color")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Button("Change") {
                                    selectedColor = currentMember.color
                                    showColorPicker = true
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Group Statistics
                    if let groupID = groupsManager.currentGroupID {
                        let groupPins = poopManager.poopPins.filter { $0.groupID == groupID }
                        VStack(alignment: .center, spacing: 12) {
                            Text("Group Statistics").font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                StatCard(title: "Total Poops", value: "\(groupPins.count)", icon: "number.circle.fill")
                                StatCard(title: "Avg Rating", value: String(format: "%.1f", calculateAverageRating(from: groupPins)), icon: "star.fill")
                                StatCard(title: "This Week", value: "\(calculatePoopsThisWeek(from: groupPins))", icon: "calendar.circle.fill")
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    // Members list with friend functionality
                    if !groupsManager.members.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Members").font(.headline)
                            VStack(spacing: 8) {
                                ForEach(groupsManager.members) { member in
                                    GroupMemberRowWithFriend(member: member, userManager: userManager)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }

                    // Group Actions
                    VStack(alignment: .leading, spacing: 8) {
                        Button(role: .destructive) {
                            showLeaveConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Leave Group")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    var body: some View {
        Group {
            if groupsManager.currentGroupID != nil {
                SimpleGroupView(
                    selectedColor: $selectedColor,
                    showColorPicker: $showColorPicker,
                    showLeaveConfirm: $showLeaveConfirm,
                    showDeleteConfirm: $showDeleteConfirm,
                    isDeleting: $isDeleting
                )
            } else {
                // Empty state (no group yet)
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("No Groups Yet").font(.title2.bold())
                        Text("Join an existing group or create one to start sharing.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button {
                                showJoin = true
                            } label: {
                                Label("Join Group", systemImage: "magnifyingglass")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)

                            Button {
                                showCreate = true
                            } label: {
                                Label("Create Group", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { menuState.currentScreen = .account } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinGroupView()
                .environmentObject(groupsManager)
        }
        .sheet(isPresented: $showCreate) {
            SearchAndCreateGroupView()
                .environmentObject(groupsManager)
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
                            if let currentUserID = auth.currentUserRecordID?.recordName,
                               let groupID = groupsManager.currentGroupID {
                                groupsManager.updateMemberColor(groupID: groupID, userID: currentUserID, newColor: selectedColor)
                            }
                            showColorPicker = false
                        }
                    }
                }
            }
        }
        .confirmationDialog("Leave this group?",
                            isPresented: $showLeaveConfirm,
                            titleVisibility: .visible) {
            Button("Leave Group", role: .destructive) {
                groupsManager.leaveGroup()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll be removed from the current group on this device. (No data will be deleted from CloudKit.)")
        }

        // Refresh members whenever the selected group changes
        .task(id: groupsManager.currentGroupID) { @Sendable in
            if let gid = groupsManager.currentGroupID {
                await groupsManager.fetchMembers(groupID: gid)
                await groupsManager.fetchCurrentGroupName()
            }
        }
    }
    
    // MARK: - Delete Functions
    private func deleteCurrentGroup() {
        guard let groupID = groupsManager.currentGroupID else { return }
        isDeleting = true
        groupsManager.deleteGroup(groupID: groupID) { result in
            DispatchQueue.main.async {
                self.isDeleting = false
                switch result {
                case .success:
                    print("✅ Successfully deleted group: \(groupID)")
                case .failure(let error):
                    print("❌ Failed to delete group: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Member Row with Friend Functionality
private struct GroupMemberRowWithFriend: View {
    let member: GroupMember
    let userManager: UserManager
    @EnvironmentObject private var auth: AuthManager
    @State private var showAddFriendAlert = false
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(member.color)
                .frame(width: 32, height: 32)
            
            Text(member.name)
                .font(.body)
            
            Spacer()
            
            // Add friend button (only if not already a friend and not yourself)
            if !userManager.friends.contains(where: { $0.id == member.userID }) &&
               member.userID != auth.currentUserRecordID?.recordName {
                Button(action: {
                    showAddFriendAlert = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                }
                .alert("Add Friend", isPresented: $showAddFriendAlert) {
                    Button("Add \(member.name)") {
                        userManager.addFriend(userID: member.userID, name: member.name)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Add \(member.name) to your friends list?")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Functions
private func calculateAverageRating(from pins: [PoopPin]) -> Double {
    guard !pins.isEmpty else { return 0.0 }
    let totalRating = pins.reduce(0) { sum, pin in
        sum + pin.tpRating + pin.cleanliness + pin.privacy + pin.plumbing + pin.overallVibes
    }
    return Double(totalRating) / Double(pins.count * 5)
}

private func findMostPopularLocation(from pins: [PoopPin]) -> String? {
    let locationCounts = Dictionary(grouping: pins, by: { $0.locationDescription })
        .mapValues { $0.count }
    return locationCounts.max(by: { $0.value < $1.value })?.key
}

private func calculateMostPoopsThisWeek(from pins: [PoopPin]) -> [LeaderboardEntry] {
    let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    let recentPins = pins.filter { $0.createdAt >= oneWeekAgo }
    
    let userCounts = Dictionary(grouping: recentPins, by: { $0.userName })
        .mapValues { $0.count }
        .sorted { $0.value > $1.value }
        .prefix(3)
    
    return userCounts.enumerated().map { index, element in
        LeaderboardEntry(
            rank: index + 1,
            name: element.key,
            value: "\(element.value) poops",
            color: .blue
        )
    }
}

private func calculateHighestAverageRating(from pins: [PoopPin]) -> [LeaderboardEntry] {
    let userRatings = Dictionary(grouping: pins, by: { $0.userName })
        .mapValues { userPins in
            let totalRating = userPins.reduce(0) { sum, pin in
                sum + pin.tpRating + pin.cleanliness + pin.privacy + pin.plumbing + pin.overallVibes
            }
            return Double(totalRating) / Double(userPins.count * 5)
        }
        .sorted { $0.value > $1.value }
        .prefix(3)
    
    return userRatings.enumerated().map { index, element in
        LeaderboardEntry(
            rank: index + 1,
            name: element.key,
            value: String(format: "%.1f", element.value),
            color: .orange
        )
    }
}

private func calculatePoopsThisWeek(from pins: [PoopPin]) -> Int {
    let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    return pins.filter { $0.createdAt >= oneWeekAgo }.count
}

// MARK: - Supporting Types
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.brown)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct LeaderboardSection: View {
    let title: String
    let entries: [LeaderboardEntry]
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brown)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.brown)
            }
            
            VStack(spacing: 4) {
                ForEach(entries, id: \.rank) { entry in
                    HStack {
                        Text("\(entry.rank)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.brown)
                            .frame(width: 20)
                        
                        Text(entry.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Text(entry.value)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(entry.color)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brown.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brown.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct LeaderboardEntry {
    let rank: Int
    let name: String
    let value: String
    let color: Color
}
