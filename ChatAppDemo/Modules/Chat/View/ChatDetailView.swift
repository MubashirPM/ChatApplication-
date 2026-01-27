//
//  ChatDetailView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI

struct ChatDetailView: View {
    let otherUser: UserModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject private var chatManager = ChatManager()
    @StateObject private var chatListViewModel = ChatListViewModel()
    @State private var chatId: String?
    @State private var isLoadingChat = true
    @State private var previousMessageCount = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header with other user info
            TitleComponentView(
                name: otherUser.name,
                imageUrl: URL(string: otherUser.photoURL)
            )
                
            // Messages with ScrollViewReader for auto-scrolling
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if chatManager.isLoading && chatManager.messages.isEmpty {
                            ProgressView()
                                .padding()
                        } else if chatManager.messages.isEmpty {
                            Text("No messages yet")
                                .foregroundStyle(.gray)
                                .padding()
                        } else {
                            ForEach(chatManager.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.senderId == authViewModel.currentUser?.id
                                )
                                .id(message.id) // Add ID for scrolling
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                .background(Color.white)
                .cornerRadius(30, corners: [.topLeft, .topRight])
                .onChange(of: chatManager.messages.count) { oldCount, newCount in
                    // Scroll to last message when new message is received
                    if newCount > previousMessageCount, let lastMessage = chatManager.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    previousMessageCount = newCount
                }
                .onAppear {
                    // Scroll to last message when view appears
                    if let lastMessage = chatManager.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input Field
            if let chatId = chatId, let currentUserId = authViewModel.currentUser?.id {
                MessageFieldView(
                    chatId: chatId,
                    senderId: currentUserId,
                    receiverId: otherUser.id ?? ""
                )
                .environmentObject(chatManager)
            }
            }
            .background(Color("peach"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setupChat()
        }
        .onAppear {
            // Mark as read immediately when view appears
            // This ensures unread badge is cleared even if user quickly navigates back
            if let chatId = chatId {
                chatListViewModel.markAsRead(chatId: chatId)
            }
        }
        .onDisappear {
            // Mark as read when leaving to ensure it's marked even if user quickly navigates back
            if let chatId = chatId {
                chatListViewModel.markAsRead(chatId: chatId)
            }
            
            // Clear active chat when leaving this view
            Task { @MainActor in
                ActiveChatTracker.shared.clearActiveChat()
            }
            
            chatManager.stopListening()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupChat() async {
        guard let currentUserId = authViewModel.currentUser?.id,
              let otherUserId = otherUser.id else {
            return
        }
        
        isLoadingChat = true
        chatId = await chatManager.getOrCreateChat(
            currentUserId: currentUserId,
            otherUserId: otherUserId
        )
        
        if let chatId = chatId {
            // IMPORTANT: Set active chat and mark as read IMMEDIATELY
            // This prevents the unread indicator from showing when returning to list
            await MainActor.run {
                ActiveChatTracker.shared.setActiveChat(chatId)
            }
            
            // Mark as read right away - this clears the unread badge
            // Called here AND in onAppear to ensure it's marked even if user quickly navigates back
            chatListViewModel.markAsRead(chatId: chatId)
            
            // Clear app badge
            NotificationManager.shared.clearBadge()
            
            // Load messages
            chatManager.loadMessages(forChatId: chatId)
        }
        
        isLoadingChat = false
    }
}

// MARK: - Title Component View

struct TitleComponentView: View {
    let name: String
    let imageUrl: URL?
    
    var body: some View {
        HStack {
            AsyncImage(url: imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.title)
                    .bold()
                Text("Online")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
//            Image(systemName: "phone.fill")
//                .foregroundStyle(.gray)
//                .padding(10)
//                .background(.white)
//                .clipShape(Circle())
        }
        .padding()
    }
}
