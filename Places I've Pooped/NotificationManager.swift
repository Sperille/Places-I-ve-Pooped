//
//  NotificationManager.swift
//  Places I've Pooped
//

import Foundation
import UserNotifications
import CloudKit
import SwiftUI

@MainActor
class NotificationManager: NSObject, ObservableObject {
    @Published var isNotificationsEnabled: Bool = false
    @Published var isAuthorized: Bool = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        checkNotificationStatus()
    }
    
    // MARK: - Request Permission
    func requestNotificationPermission() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
                self.isNotificationsEnabled = granted
                UserDefaults.standard.set(granted, forKey: "notifications.enabled")
            }
            
            if granted {
                await registerForRemoteNotifications()
                await setupCloudKitSubscriptions()
            }
        } catch {
            print("❌ Failed to request notification permission: \(error)")
        }
    }
    
    // MARK: - Check Status
    func checkNotificationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                self.isNotificationsEnabled = UserDefaults.standard.bool(forKey: "notifications.enabled")
            }
        }
    }
    
    // MARK: - Toggle Notifications
    func toggleNotifications() {
        if isNotificationsEnabled {
            disableNotifications()
        } else {
            Task {
                await requestNotificationPermission()
            }
        }
    }
    
    func disableNotifications() {
        isNotificationsEnabled = false
        UserDefaults.standard.set(false, forKey: "notifications.enabled")
        
        // Remove CloudKit subscriptions
        Task {
            await removeCloudKitSubscriptions()
        }
    }
    
    // MARK: - Remote Notifications
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - CloudKit Subscriptions
    private func setupCloudKitSubscriptions() async {
        // Try to get user ID from multiple sources
        let userID = UserDefaults.standard.string(forKey: "auth.user.recordName") ?? 
                    UserDefaults.standard.string(forKey: "auth.apple.userID")
        
        guard let userID = userID else {
            print("❌ No user ID found for notification subscriptions")
            return
        }
        
        // Remove existing subscriptions first
        await removeCloudKitSubscriptions()
        
        // Create subscription for group member poops
        await createGroupPoopSubscription(userID: userID)
        
        // Create subscription for friend poops
        await createFriendPoopSubscription(userID: userID)
    }
    
    private func createGroupPoopSubscription(userID: String) async {
        let predicate = NSPredicate(format: "userID != %@ AND groupID != nil", userID)
        let subscription = CKQuerySubscription(
            recordType: "PoopPin",
            predicate: predicate,
            subscriptionID: "group-poops-\(userID)",
            options: [.firesOnRecordCreation]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.title = "New Group Poop! 💩"
        notification.alertBody = "%@ just dropped a pin"
        notification.shouldBadge = true
        notification.soundName = "default"
        
        subscription.notificationInfo = notification
        
        do {
            try await CKEnv.publicDB.save(subscription)
            print("✅ Created group poop subscription")
        } catch {
            print("❌ Failed to create group poop subscription: \(error)")
        }
    }
    
    private func createFriendPoopSubscription(userID: String) async {
        // Get user's friends list
        let friends = UserDefaults.standard.stringArray(forKey: "user.friends") ?? []
        
        if !friends.isEmpty {
            let predicate = NSPredicate(format: "userID IN %@", friends)
            let subscription = CKQuerySubscription(
                recordType: "PoopPin",
                predicate: predicate,
                subscriptionID: "friend-poops-\(userID)",
                options: [.firesOnRecordCreation]
            )
            
                    let notification = CKSubscription.NotificationInfo()
        notification.title = "Your Friend Just Pooped! 💩"
        notification.alertBody = "%@ just pooped"
        notification.shouldBadge = true
        notification.soundName = "default"
            
            subscription.notificationInfo = notification
            
            do {
                try await CKEnv.publicDB.save(subscription)
                print("✅ Created friend poop subscription")
            } catch {
                print("❌ Failed to create friend poop subscription: \(error)")
            }
        }
    }
    
    private func removeCloudKitSubscriptions() async {
        let userID = UserDefaults.standard.string(forKey: "auth.user.recordName") ?? 
                    UserDefaults.standard.string(forKey: "auth.apple.userID")
        guard let userID = userID else { return }
        
        let subscriptionIDs = [
            "group-poops-\(userID)",
            "friend-poops-\(userID)"
        ]
        
        for subscriptionID in subscriptionIDs {
            do {
                try await CKEnv.publicDB.deleteSubscription(withID: subscriptionID)
                print("✅ Removed subscription: \(subscriptionID)")
            } catch {
                print("❌ Failed to remove subscription \(subscriptionID): \(error)")
            }
        }
    }
    
    // MARK: - Handle Remote Notifications
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard let ck = userInfo["ck"] as? [String: Any],
              let qry = ck["qry"] as? [String: Any],
              let rec = qry["rec"] as? [String: Any],
              let poopID = rec["recordName"] as? String else {
            return
        }
        
        // Fetch the poop details to show in notification
        Task {
            await fetchPoopDetails(for: poopID)
        }
    }
    
    private func fetchPoopDetails(for poopID: String) async {
        let recordID = CKRecord.ID(recordName: poopID)
        
        do {
            let record = try await CKEnv.publicDB.record(for: recordID)
            let userName = record["userName"] as? String ?? "Someone"
            let locationDescription = record["locationDescription"] as? String ?? "somewhere"
            
            // Show local notification with details
            await showLocalNotification(
                title: "New Poop!",
                body: "\(userName) just logged a poop at \(locationDescription)"
            )
        } catch {
            print("❌ Failed to fetch poop details: \(error)")
        }
    }
    
    private func showLocalNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("❌ Failed to show local notification: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        completionHandler()
    }
}
