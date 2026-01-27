//
//  ChatListViewModel.swift
//  ChatAppDemo
//
//  Created by Antigravity on 21/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

struct RecentChat: Identifiable {
    let id: String
    let chat: ChatModel
    let otherUser: UserModel?
}

@MainActor
class ChatListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var recentChats: [RecentChat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var previousChatIds: Set<String> = [] // Track which chats we've seen
    
    // MARK: - Public Methods
    func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // Query chats where user is a participant
        // Sort by lastMessageTimestamp descending to show latest chats first
        // NOTE: This query requires a Composite Index in Firestore
        // (participants Array + lastMessageTimestamp Descending)
        let query = db.collection("Chats")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastMessageTimestamp", descending: true)
            
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Error loading chats: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                self.recentChats = []
                self.isLoading = false
                return
            }
            
            // Check for new messages and trigger notifications
            Task { @MainActor in
                await self.checkForNewMessages(documents: documents, currentUserId: currentUserId)
            }
            
            self.loadChatsDetails(from: documents, currentUserId: currentUserId)
        }
    }
    
    func stopListening() {
        listener?.remove()
        recentChats = []
    }
    
    // MARK: - Private Methods
    
    /// Check for new messages and show notifications
    /// Only shows notifications for chats that are NOT currently being viewed
    private func checkForNewMessages(documents: [QueryDocumentSnapshot], currentUserId: String) async {
        for document in documents {
            do {
                let chat = try document.data(as: ChatModel.self)
                let chatId = chat.id ?? document.documentID
                
                // Check if this is a new message (chat exists but has unread count)
                let hasUnread = chat.hasNewMessage(for: currentUserId)
                let isNewChat = !previousChatIds.contains(chatId)
                
                // BEST PRACTICE: Don't show notification if user is currently viewing this chat
                let isActiveChat = await ActiveChatTracker.shared.isActive(chatId: chatId)
                
                if hasUnread && !isNewChat && !isActiveChat {
                    // This chat has a new unread message AND user is NOT viewing it - show notification
                    if let otherUserId = chat.getOtherParticipantId(currentUserId: currentUserId),
                       let lastMessage = chat.lastMessage {
                        
                        // Fetch sender's name
                        let userDoc = try? await db.collection("Users").document(otherUserId).getDocument()
                        let user = try? userDoc?.data(as: UserModel.self)
                        let senderName = user?.name ?? user?.email ?? "Someone"
                        
                        // Show notification
                        NotificationManager.shared.showMessageNotification(
                            senderName: senderName,
                            messageText: lastMessage,
                            chatId: chatId
                        )
                        
                        print("📬 Notification shown for chat: \(chatId) from \(senderName)")
                    }
                } else if isActiveChat {
                    print("🔕 Notification suppressed - chat is currently active: \(chatId)")
                }
                
                // Track this chat
                previousChatIds.insert(chatId)
            } catch {
                debugPrint("Error checking for new messages: \(error)")
            }
        }
    }
    
    private func loadChatsDetails(from documents: [QueryDocumentSnapshot], currentUserId: String) {
        Task {
            var loadedChats: [RecentChat] = []
            
            for document in documents {
                do {
                    let chat = try document.data(as: ChatModel.self)
                    
                    // Identify other user
                    if let otherUserId = chat.getOtherParticipantId(currentUserId: currentUserId) {
                        // Fetch user details
                        // In a production app, we should cache users to avoid repeated fetches
                        let userDoc = try? await db.collection("Users").document(otherUserId).getDocument()
                        let user = try? userDoc?.data(as: UserModel.self)
                        
                        let recentChat = RecentChat(
                            id: chat.id ?? document.documentID,
                            chat: chat,
                            otherUser: user
                        )
                        loadedChats.append(recentChat)
                    }
                } catch {
                    debugPrint("Error decoding chat: \(error)")
                }
            }
            
            // Assign to published property on MainActor
            self.recentChats = loadedChats
            self.isLoading = false
        }
    }
    
    // MARK: - Mark as Read
    
    /// Mark a chat as read (clear unread count for current user)
    /// This ensures notification badges don't show when user returns to chat list
    func markAsRead(chatId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("📖 Marking chat as read: \(chatId)")
        
        // Use async/await for better reliability
        Task {
            do {
                try await db.collection("Chats").document(chatId).updateData([
                    "unreadCount.\(currentUserId)": 0
                ])
                    print("✅ Chat marked as read: \(chatId)")
            } catch {
                print("❌ Error marking chat as read: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        listener?.remove()
    }
}
