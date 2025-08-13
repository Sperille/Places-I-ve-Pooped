//
//  PlacesIvePoopedApp.swift
//  Places I've Pooped
//

import SwiftUI

@main
struct PlacesIvePoopedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("overrideSystemAppearance") private var overrideSystemAppearance: Bool = false
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
                // Set initial appearance based on user preference
                updateAppearance()
            }
            .onChange(of: isDarkMode) { _, _ in
                updateAppearance()
            }
            .onChange(of: overrideSystemAppearance) { _, _ in
                updateAppearance()
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
    
    private func updateAppearance() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                if overrideSystemAppearance {
                    // User has chosen to override system preference
                    window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                } else {
                    // Follow system preference
                    window.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
    }
}
