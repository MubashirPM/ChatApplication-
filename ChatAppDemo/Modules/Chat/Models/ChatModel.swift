//
//  ChatModel.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Foundation
import FirebaseFirestore

/// Model representing a chat between two users
struct ChatModel: Identifiable, Codable {
    @DocumentID var id: String?
    let participants: [String] // Array of user IDs
    let lastMessage: String?
    let lastMessageTimestamp: Date?
    let lastMessageSenderId: String? // ID of who sent the last message
    let createdAt: Date
    let unreadCount: [String: Int]? // Dictionary: [userId: unreadCount]
    
    /// Get the other participant's ID (not the current user)
    func getOtherParticipantId(currentUserId: String) -> String? {
        participants.first { $0 != currentUserId }
    }
    
    /// Get unread count for current user
    func getUnreadCount(for userId: String) -> Int {
        return unreadCount?[userId] ?? 0
    }
    
    /// Check if there's a new message for current user
    func hasNewMessage(for currentUserId: String) -> Bool {
        // Check if last message was NOT sent by current user
        guard let senderId = lastMessageSenderId else { return false }
        return senderId != currentUserId && getUnreadCount(for: currentUserId) > 0
    }
}
