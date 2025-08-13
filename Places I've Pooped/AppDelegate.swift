//
//  AppDelegate.swift
//  Places I've Pooped
//
//  Created by Steven Perille on 8/4/25.
//


import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ Device Token: \(token)")
        // You’ll send this to your backend to target this device
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Handle CloudKit push notifications
        if let _ = userInfo["ck"] as? [String: Any] {
            // This is a CloudKit notification
            print("📱 Received CloudKit notification: \(userInfo)")
            
            if let notificationManager = getNotificationManager() {
                notificationManager.handleRemoteNotification(userInfo)
            }
            
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
    
    private func getNotificationManager() -> NotificationManager? {
        // Get the notification manager from the app's environment
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let _ = window.rootViewController else {
            return nil
        }

        return nil
    }
}
