//
//  AccountView.swift
//  Places I've Pooped
//
//

import SwiftUI
import CloudKit

struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var poopManager: PoopManager
    @EnvironmentObject private var groupsManager: GroupsManager
    @EnvironmentObject private var menuState: MenuState

    @EnvironmentObject private var userManager: UserManager
    @State private var showSettings = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                    Text(displayEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                
                // Current group (if any)
                if let _ = groupsManager.currentGroupID, let gname = groupsManager.currentGroupName {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Group").font(.headline)
                        HStack(spacing: 10) {
                            Image(systemName: "person.3")
                            Text(gname)
                            Spacer()
                        }
                    }
                }
                

                

                
                // My Statistics
                VStack(alignment: .center, spacing: 12) {
                    Text("My Statistics").font(.headline)
                    
                    let myPins = getMyPins()
                    if myPins.isEmpty {
                        Text("You haven't logged any poops yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        // Calculate statistics
                        let totalPoops = myPins.count
                        let averageRating = calculateAverageRating(from: myPins)
                        let recentActivity = calculateRecentActivity(from: myPins)
                        
                        VStack(spacing: 16) {
                            // Statistics Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                StatCard(title: "Total Poops", value: "\(totalPoops)", icon: "number.circle.fill")
                                StatCard(title: "Avg Rating", value: String(format: "%.1f", averageRating), icon: "star.fill")
                                StatCard(title: "This Week", value: "\(recentActivity)", icon: "calendar.circle.fill")
                            }
                            
                            // Most Visited Location
                            if let mostVisited = findMostVisitedLocation(from: myPins) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Most Visited")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(mostVisited)
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                
                // My recent poops
                VStack(alignment: .center, spacing: 8) {
                    Text("My Poops").font(.headline)
                    
                    let myPins = getMyPins()
                    if myPins.isEmpty {
                        Text("You haven't logged any poops yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(myPins) { pin in
                                NavigationLink { PoopDetailView(poop: pin) } label: {
                                    PoopInlineRow(pin: pin)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        poopManager.deletePoopPin(pin)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Settings")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { signOut() } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .accessibilityLabel("Sign Out")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(isDarkMode: $isDarkMode)
            }
            // Load when user resolves / when they change
            .task(id: auth.currentUserRecordID) {
                poopManager.fetchPoopPins()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayName: String {
        // Try to get name from multiple sources
        let authName = auth.currentUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultsName = UserDefaults.standard.string(forKey: "auth.displayName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use auth name if available, otherwise try UserDefaults, otherwise fallback
        let finalName = authName.isEmpty ? (defaultsName ?? "User") : authName
        

        
        return finalName
    }
    
    private var displayEmail: String {
        auth.currentUserEmail.isEmpty ? " " : auth.currentUserEmail
    }
    
    // MARK: - Helper Functions
    
    private func getMyPins() -> [PoopPin] {
        guard let userID = auth.currentUserRecordID?.recordName else { return [] }
        return poopManager.poopPins
            .filter { $0.userID == userID }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    // MARK: - Actions
    
    private func signOut() {
        groupsManager.leaveGroup()
        auth.signOut()
        menuState.currentScreen = .dashboard
    }
    
    private func deletePoop(offsets: IndexSet) {
        let myPins = getMyPins()
        for index in offsets {
            let pin = myPins[index]
            poopManager.deletePoopPin(pin)
        }
    }
    
    
    private func calculateAverageRating(from pins: [PoopPin]) -> Double {
        guard !pins.isEmpty else { return 0.0 }
        let totalRating = pins.reduce(0) { sum, pin in
            sum + pin.tpRating + pin.cleanliness + pin.privacy + pin.plumbing + pin.overallVibes
        }
        return Double(totalRating) / Double(pins.count * 5)
    }
    
    private func calculateRecentActivity(from pins: [PoopPin]) -> Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return pins.filter { $0.createdAt >= oneWeekAgo }.count
    }
    
    private func findMostVisitedLocation(from pins: [PoopPin]) -> String? {
        let locationCounts = Dictionary(grouping: pins) { pin in
            pin.locationDescription.isEmpty ? "Unknown Location" : pin.locationDescription
        }.mapValues { $0.count }
        
        guard let mostVisited = locationCounts.max(by: { $0.value < $1.value }) else { return nil }
        return mostVisited.key
    }
    
    
    private struct PoopInlineRow: View {
        let pin: PoopPin
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pin.userName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(Self.formatDate(pin.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !pin.locationDescription.isEmpty {
                    Text(pin.locationDescription).font(.subheadline)
                }
                if !pin.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(pin.comment)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        
        private static func formatDate(_ date: Date) -> String {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return f.localizedString(for: date, relativeTo: Date())
        }
    }
}

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


