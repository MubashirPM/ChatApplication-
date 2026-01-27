//
//  ActiveChatTracker.swift
//  ChatAppDemo
//
//  Tracks which chat is currently being viewed to suppress notifications
//

import Foundation
import Combine

/// Singleton to track which chat is currently active (being viewed)
/// This prevents notifications from showing for the currently viewed chat
@MainActor
class ActiveChatTracker: ObservableObject {
    
    static let shared = ActiveChatTracker()
    
    /// The ID of the chat currently being viewed (nil if not viewing any chat)
    @Published var activeChatId: String?
    
    private init() {}
    
    /// Set the active chat ID when user opens a chat
    func setActiveChat(_ chatId: String?) {
        activeChatId = chatId
        print("🔍 Active chat set to: \(chatId ?? "none")")
    }
    
    /// Clear the active chat when user leaves the chat view
    func clearActiveChat() {
        activeChatId = nil
        print("🔍 Active chat cleared")
    }
    
    /// Check if a specific chat is currently active
    func isActive(chatId: String) -> Bool {
        return activeChatId == chatId
    }
}
