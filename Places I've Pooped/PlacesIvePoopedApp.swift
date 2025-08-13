//
//  PlacesIvePoopedApp.swift
//  Places I've Pooped
//

import SwiftUI

@main
struct PlacesIvePoopedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth            = AuthManager()
    @StateObject private var menuState       = MenuState()
    @StateObject private var sessionManager  = SessionManager()
    @StateObject private var groupsManager   = GroupsManager()
    @StateObject private var poopManager     = PoopManager()
    @StateObject private var userManager     = UserManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()

    var body: some Scene {
        WindowGroup {
            AppRootView()
            // Rehydrate saved session (Apple or email) on launch
            .onAppear {
                auth.rehydrateOnLaunch()
            }
            // Provide environment objects
            .environmentObject(auth)
            .environmentObject(menuState)
            .environmentObject(sessionManager)
            .environmentObject(groupsManager)
            .environmentObject(poopManager)
            .environmentObject(userManager)
            .environmentObject(locationManager)
            .environmentObject(notificationManager)
            .keyboardDoneToolbar()
        }
    }
}
