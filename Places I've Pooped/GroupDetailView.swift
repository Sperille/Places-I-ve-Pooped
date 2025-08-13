//
//  GroupDetailView.swift
//  Places I've Pooped
//

import SwiftUI

struct GroupDetailView: View {
    let groupID: String
    let groupName: String
    
    @EnvironmentObject private var groupsManager: GroupsManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var poopManager: PoopManager
    
    @State private var showColorPicker = false
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        List {
            Section("Group Info") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(groupName)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.vertical, 4)
            }
            
            // Current user's color editing section
            if let currentUserID = auth.currentUserRecordID?.recordName,
               let currentMember = groupsManager.members.first(where: { $0.userID == currentUserID }) {
                Section("Your Color") {
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
                    .padding(.vertical, 4)
                }
            }
            
            // Group Statistics
            let groupPins = poopManager.poopPins.filter { $0.groupID == groupID }
            if !groupPins.isEmpty {
                Section("Group Statistics") {
                    VStack(spacing: 16) {
                        // Statistics Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            StatCard(title: "Total Poops", value: "\(groupPins.count)", icon: "number.circle.fill")
                            StatCard(title: "Avg Rating", value: String(format: "%.1f", calculateAverageRating(from: groupPins)), icon: "star.fill")
                            StatCard(title: "Members", value: "\(groupsManager.members.count)", icon: "person.3.fill")
                        }
                        
                        // Most Popular Location
                        if let mostPopular = findMostPopularLocation(from: groupPins) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Most Popular Location")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(mostPopular)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                
                // Leaderboards
                Section("Leaderboards") {
                    VStack(spacing: 16) {
                        // Most Poops This Week
                        LeaderboardSection(
                            title: "Most Poops This Week",
                            entries: calculateMostPoopsThisWeek(from: groupPins),
                            icon: "calendar.circle.fill"
                        )
                        
                        // Highest Average Rating
                        LeaderboardSection(
                            title: "Highest Average Rating",
                            entries: calculateHighestAverageRating(from: groupPins),
                            icon: "star.circle.fill"
                        )
                    }
                }
            }
            
            if !groupsManager.members.isEmpty {
                Section("Members (\(groupsManager.members.count))") {
                    ForEach(groupsManager.members) { member in
                        GroupMemberRow(member: member)
                    }
                }
            } else {
                Section("Members") {
                    Text("No members found")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .navigationTitle("Group Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            groupsManager.fetchMembers(groupID: groupID)
        }
        .sheet(isPresented: $showColorPicker) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Choose Your Color")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("This color will be used for your map pins")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    ColorPicker("Select Color", selection: $selectedColor)
                        .labelsHidden()
                        .scaleEffect(1.5)
                    
                    // Color preview
                    HStack(spacing: 16) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(radius: 2)
                        
                        Text("Preview")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Change Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showColorPicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            updateUserColor()
                            showColorPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private func updateUserColor() {
        guard let currentUserID = auth.currentUserRecordID?.recordName else { return }
        
        // Update the user's color in the group
        groupsManager.updateMemberColor(groupID: groupID, userID: currentUserID, newColor: selectedColor)
        
        // Also save to UserDefaults as fallback
        UserDefaults.standard.set(selectedColor.toHex(), forKey: "user.color.hex")
    }
    
    // MARK: - Statistics Helper Functions
    
    private func calculateAverageRating(from pins: [PoopPin]) -> Double {
        guard !pins.isEmpty else { return 0.0 }
        let totalRating = pins.reduce(0) { sum, pin in
            sum + pin.tpRating + pin.cleanliness + pin.privacy + pin.plumbing + pin.overallVibes
        }
        return Double(totalRating) / Double(pins.count * 5) // 5 rating categories
    }
    
    private func findMostPopularLocation(from pins: [PoopPin]) -> String? {
        let locationCounts = Dictionary(grouping: pins) { pin in
            pin.locationDescription.isEmpty ? "Unknown Location" : pin.locationDescription
        }.mapValues { $0.count }
        
        guard let mostPopular = locationCounts.max(by: { $0.value < $1.value }) else { return nil }
        return mostPopular.key
    }
    
    private func calculateMostPoopsThisWeek(from pins: [PoopPin]) -> [LeaderboardEntry] {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentPins = pins.filter { $0.createdAt >= oneWeekAgo }
        
        let memberCounts = Dictionary(grouping: recentPins) { $0.userName }.mapValues { $0.count }
        
        return memberCounts.sorted { $0.value > $1.value }.prefix(5).map { name, count in
            LeaderboardEntry(name: name, value: Double(count), unit: "poops")
        }
    }
    
    private func calculateHighestAverageRating(from pins: [PoopPin]) -> [LeaderboardEntry] {
        let memberRatings = Dictionary(grouping: pins) { $0.userName }.mapValues { memberPins in
            calculateAverageRating(from: memberPins)
        }
        
        return memberRatings.sorted { $0.value > $1.value }.prefix(5).map { name, rating in
            LeaderboardEntry(name: name, value: rating, unit: "stars")
        }
    }
}

// MARK: - Member Row (reused from GroupsView)

private struct GroupMemberRow: View {
    let member: GroupMember

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(member.color)
                .frame(width: 12, height: 12)

            Text(member.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(member.joinedAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - StatCard Component
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

// MARK: - LeaderboardSection Component
private struct LeaderboardSection: View {
    let title: String
    let entries: [LeaderboardEntry]
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brown)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            if entries.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Text("\(index + 1)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.brown)
                                .frame(width: 24)
                            
                            Text(entry.name)
                                .font(.body)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(String(format: "%.1f", entry.value))
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(entry.unit)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - LeaderboardEntry
private struct LeaderboardEntry {
    let name: String
    let value: Double
    let unit: String
}
