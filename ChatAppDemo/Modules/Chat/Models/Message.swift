//
//  Message.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 14/01/26.
//

import Foundation
import FirebaseFirestore

enum MessageType: String, Codable {
    case text
    case audio
}

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    let text: String
    let senderId: String
    let receiverId: String
    let timestamp: Date
    let messageType: MessageType
    let audioURL: String?
    let audioDuration: Double? // Duration in seconds
    
    init(
        id: String? = nil,
        text: String,
        senderId: String,
        receiverId: String,
        timestamp: Date,
        messageType: MessageType = .text,
        audioURL: String? = nil,
        audioDuration: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.senderId = senderId
        self.receiverId = receiverId
        self.timestamp = timestamp
        self.messageType = messageType
        self.audioURL = audioURL
        self.audioDuration = audioDuration
    }
    
    // Computed property for backward compatibility
    var received: Bool {
        // This will be computed based on current user in the view
        false
    }
}
