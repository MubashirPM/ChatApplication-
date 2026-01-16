//
//  Message.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 14/01/26.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    let text: String
    let senderId: String
    let receiverId: String
    let timestamp: Date
    
    // Computed property for backward compatibility
    var received: Bool {
        // This will be computed based on current user in the view
        false
    }
}
