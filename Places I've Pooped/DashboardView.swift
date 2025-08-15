//
//  DashboardView.swift
//  Places I've Pooped
//

import SwiftUI
import CoreLocation
import CloudKit

struct DashboardView: View {
    @EnvironmentObject private var menuState: MenuState
    @EnvironmentObject private var poopManager: PoopManager
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var groupsManager: GroupsManager
    @EnvironmentObject private var userManager: UserManager

    // Remove separate state variables - use PoopManager.poopPins directly

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let combined = mergeAllPins()
                if combined.isEmpty {
                    FallbackEmpty(allEmpty: true)
                } else {
                    VStack(spacing: 8) {
                        ForEach(combined) { pin in
                            NavigationLink { PoopDetailView(poop: pin) } label: {
                                PoopInlineCard(pin: pin)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // restore Account button (no refresh icon)
            ToolbarItem(placement: .topBarTrailing) {
                Button { menuState.currentScreen = .account } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title2)
                }
                .accessibilityLabel("Account")
            }
        }
        .task {
            poopManager.fetchPoopPins()              // shared cache (MapView uses this too)
        }
    }

    // MARK: - Data helpers (no layout change)
    private func viewerID() -> String? {
        // ✅ fallback to UserManager if AuthManager recordID is nil
        auth.currentUserRecordID?.recordName ?? userManager.currentUserID
    }

    private func mergeAllPins() -> [PoopPin] {
        let uid = viewerID()
        let gid = groupsManager.currentGroupID
        let friendIDs = userManager.friends.map { $0.id }
        
        print("🔍 Dashboard filtering - User ID: \(uid ?? "nil")")
        print("🔍 Dashboard filtering - Group ID: \(gid ?? "nil")")
        print("🔍 Dashboard filtering - Friend IDs: \(friendIDs)")
        print("🔍 Dashboard filtering - Total poops: \(poopManager.poopPins.count)")
        
        // Simulator debug info
        #if targetEnvironment(simulator)
        print("🖥️ Simulator Debug:")
        print("  - PoopManager poopPins count: \(poopManager.poopPins.count)")
        print("  - PoopManager poopPins: \(poopManager.poopPins.map { "\($0.userName) (\($0.id))" })")
        print("  - GroupsManager currentGroupID: \(groupsManager.currentGroupID ?? "nil")")
        print("  - UserManager friends count: \(userManager.friends.count)")
        #endif
        
        // Filter poopPins based on current user, group, and friends
        let filteredPins = poopManager.poopPins.filter { pin in
            print("🔍 Checking poop: \(pin.id) by \(pin.userName)")
            print("  - Pin userID: \(pin.userID)")
            print("  - Pin groupID: \(pin.groupID ?? "nil")")
            print("  - Current userID: \(uid ?? "nil")")
            print("  - Current groupID: \(gid ?? "nil")")
            print("  - Friend IDs: \(friendIDs)")
            
            // Show user's own poops
            if pin.userID == uid { 
                print("✅ Showing own poop: \(pin.id)")
                return true 
            }
            // Show group poops if user is in a group (including historical)
            if let gid = gid, !gid.isEmpty, pin.groupID == gid { 
                print("✅ Showing group poop: \(pin.id) by \(pin.userName)")
                return true 
            }
            // Show friends' poops
            if !friendIDs.isEmpty, friendIDs.contains(pin.userID) { 
                print("✅ Showing friend poop: \(pin.id) by \(pin.userName)")
                return true 
            }
            print("❌ Filtered out poop: \(pin.id) by \(pin.userName) (userID: \(pin.userID), groupID: \(pin.groupID ?? "nil"))")
            return false
        }
        
        print("🔍 Dashboard filtering - Filtered poops: \(filteredPins.count)")
        return filteredPins.sorted(by: { $0.createdAt > $1.createdAt })
    }
}
// MARK: - Empty State (unchanged visuals)
private struct FallbackEmpty: View {
    let allEmpty: Bool
    var body: some View {
        Group {
            if allEmpty {
                VStack(spacing: 6) {
                    Text("No poops logged yet").font(.headline)
                    Text("Tap “Log a Poop” to add your first one.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Inline Card (unchanged visuals)
private struct PoopInlineCard: View {
    let pin: PoopPin

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(pin.userName).font(.headline).lineLimit(1)
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
