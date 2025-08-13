//
//  ContentView.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 7/3/25.
//

import SwiftUI

enum ActiveSheet: Identifiable {
    case logPoop, account, settings
    var id: Int { hashValue }
}

struct ContentView: View {
    @EnvironmentObject var menuState: MenuState
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var groupsManager: GroupsManager

    @State private var activeSheet: ActiveSheet?

    var body: some View {
        NavigationStack {
            ZStack { mainBody }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .logPoop:   LogPoopView()
                case .account:   AccountView()
                case .settings:  SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    LogPoopBar { activeSheet = .logPoop }
                    BottomBar(current: $menuState.currentScreen)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private var mainBody: some View {
        switch menuState.currentScreen {
        case .dashboard: DashboardView()
        case .map:       MapView()
        case .groups:    GroupsView()
        case .friends:   AddFriendView()
        case .account:   AccountView()
        case .settings:  SettingsView()
        }
    }
}
