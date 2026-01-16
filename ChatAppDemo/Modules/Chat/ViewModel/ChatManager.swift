//
//  ChatManager.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Foundation
import FirebaseFirestore
// TODO: Add FirebaseStorage package dependency in Xcode
// import FirebaseStorage
import Combine

/// ViewModel for managing chats and messages
@MainActor
class ChatManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    // TODO: Uncomment after adding FirebaseStorage package
    // private let storage = Storage.storage()
    private var messagesListener: ListenerRegistration?
    private var currentChatId: String?
    
    // MARK: - Public Methods
    
    /// Get or create a chat between two users
    func getOrCreateChat(currentUserId: String, otherUserId: String) async -> String? {
        isLoading = true
        
        // Check if chat already exists
        let chatsQuery = db.collection("Chats")
            .whereField("participants", arrayContains: currentUserId)
        
        do {
            let snapshot = try await chatsQuery.getDocuments()
            
            // Find chat with both participants
            for document in snapshot.documents {
                if let chat = try? document.data(as: ChatModel.self),
                   chat.participants.contains(otherUserId) {
                    isLoading = false
                    return document.documentID
                }
            }
            
            // Create new chat if doesn't exist
            let newChat = ChatModel(
                id: nil,
                participants: [currentUserId, otherUserId].sorted(),
                lastMessage: nil,
                lastMessageTimestamp: nil,
                createdAt: Date()
            )
            
            let chatRef = try await db.collection("Chats").addDocument(from: newChat)
            isLoading = false
            return chatRef.documentID
            
        } catch {
            errorMessage = "Error creating chat: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    /// Load messages for a specific chat
    func loadMessages(forChatId chatId: String) {
        currentChatId = chatId
        messagesListener?.remove()
        
        messagesListener = db.collection("Chats")
            .document(chatId)
            .collection("Messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Error fetching messages: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.messages = []
                    return
                }
                
                self.messages = documents.compactMap { document -> Message? in
                    do {
                        return try document.data(as: Message.self)
                    } catch {
                        debugPrint("Error decoding message: \(error.localizedDescription)")
                        return nil
                    }
                }
            }
    }
    
    /// Send a text message in a chat
    func sendMessage(text: String, chatId: String, senderId: String, receiverId: String) {
        let message = Message(
            id: nil,
            text: text,
            senderId: senderId,
            receiverId: receiverId,
            timestamp: Date(),
            messageType: .text
        )
        
        do {
            let messageRef = db.collection("Chats")
                .document(chatId)
                .collection("Messages")
                .document()
            
            try messageRef.setData(from: message)
            
            // Update chat's last message
            db.collection("Chats").document(chatId).updateData([
                "lastMessage": text,
                "lastMessageTimestamp": Date()
            ])
            
        } catch {
            errorMessage = "Error sending message: \(error.localizedDescription)"
        }
    }
    
    /// Send a voice message in a chat
    /// NOTE: Requires FirebaseStorage package to be added in Xcode
    func sendVoiceMessage(
        audioURL: URL,
        duration: Double,
        chatId: String,
        senderId: String,
        receiverId: String
    ) async {
        isLoading = true
        
        // TODO: Uncomment after adding FirebaseStorage package dependency
        /*
        // Upload audio file to Firebase Storage
        let fileName = "voiceMessages/\(UUID().uuidString).m4a"
        let storageRef = storage.reference().child(fileName)
        
        do {
            // Upload the audio file
            _ = try await storageRef.putFile(from: audioURL)
            
            // Get the download URL
            let downloadURL = try await storageRef.downloadURL()
            
            // Create message with audio URL
            let message = Message(
                id: nil,
                text: "🎤 Voice message",
                senderId: senderId,
                receiverId: receiverId,
                timestamp: Date(),
                messageType: .audio,
                audioURL: downloadURL.absoluteString,
                audioDuration: duration
            )
            
            let messageRef = db.collection("Chats")
                .document(chatId)
                .collection("Messages")
                .document()
            
            try messageRef.setData(from: message)
            
            // Update chat's last message
            db.collection("Chats").document(chatId).updateData([
                "lastMessage": "🎤 Voice message",
                "lastMessageTimestamp": Date()
            ])
            
            // Delete local file after upload
            try? FileManager.default.removeItem(at: audioURL)
            
            isLoading = false
            
        } catch {
            errorMessage = "Error sending voice message: \(error.localizedDescription)"
            isLoading = false
        }
        */
        
        // Temporary: Store audio as base64 in Firestore (not recommended for production)
        // This is a workaround until FirebaseStorage is added
        do {
            let audioData = try Data(contentsOf: audioURL)
            let base64Audio = audioData.base64EncodedString()
            
            let message = Message(
                id: nil,
                text: "🎤 Voice message",
                senderId: senderId,
                receiverId: receiverId,
                timestamp: Date(),
                messageType: .audio,
                audioURL: base64Audio, // Temporarily storing as base64
                audioDuration: duration
            )
            
            let messageRef = db.collection("Chats")
                .document(chatId)
                .collection("Messages")
                .document()
            
            try messageRef.setData(from: message)
            
            try await db.collection("Chats").document(chatId).updateData([
                "lastMessage": "🎤 Voice message",
                "lastMessageTimestamp": Date()
            ])
            
            // Delete local file
            try? FileManager.default.removeItem(at: audioURL)
            
            isLoading = false
            
        } catch {
            errorMessage = "Error sending voice message: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Stop listening to messages
    func stopListening() {
        messagesListener?.remove()
        messagesListener = nil
        messages = []
        currentChatId = nil
    }
    
    deinit {
        messagesListener?.remove()
    }
}
