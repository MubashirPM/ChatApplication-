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
    let createdAt: Date
    
    /// Get the other participant's ID (not the current user)
    func getOtherParticipantId(currentUserId: String) -> String? {
        participants.first { $0 != currentUserId }
    }
}
