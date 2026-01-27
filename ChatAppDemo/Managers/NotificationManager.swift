//
//  NotificationManager.swift
//  ChatAppDemo
//
//  Simple local notification manager (NO Apple Developer Account needed)
//  Works when app is open or in background
//

import Foundation
import UserNotifications

/// Manages local notifications for incoming messages
class NotificationManager {
    
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Request Permission
    
    /// Request notification permission from user (shows iOS dialog)
    /// Call this once when user logs in
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }
    
    // MARK: - Show Local Notification
    
    /// Show a local notification for a new message
    /// - Parameters:
    ///   - senderName: Name of person who sent the message
    ///   - messageText: The message content
    ///   - chatId: ID of the chat (for deep linking if needed later)
    func showMessageNotification(senderName: String, messageText: String, chatId: String) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = messageText
        content.sound = .default
        content.badge = 1
        
        // Add chat ID for future deep linking
        content.userInfo = ["chatId": chatId]
        
        // Create trigger (show immediately)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request with unique ID
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error showing notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification sent: \(senderName) - \(messageText)")
            }
        }
    }
    
    // MARK: - Clear Badge
    
    /// Clear the app badge count
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
