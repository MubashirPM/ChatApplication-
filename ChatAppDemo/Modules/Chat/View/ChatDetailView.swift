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
    @State private var chatId: String?
    @State private var isLoadingChat = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with other user info
            TitleComponentView(
                name: otherUser.name,
                imageUrl: URL(string: otherUser.photoURL)
            )
            
            // Messages
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
                        }
                    }
                }
                .padding(.top, 10)
            }
            .background(Color.white)
            .cornerRadius(30, corners: [.topLeft, .topRight])
            
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
        .onDisappear {
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
            
            Image(systemName: "phone.fill")
                .foregroundStyle(.gray)
                .padding(10)
                .background(.white)
                .clipShape(Circle())
        }
        .padding()
    }
}


#Preview {
    NavigationStack {
        ChatDetailView(
            otherUser: UserModel(
                id: "123",
                name: "John Doe",
                email: "john@example.com",
                photoURL: "",
                createdAt: Date()
            )
        )
        .environmentObject(AuthenticationViewModel())
    }
}
