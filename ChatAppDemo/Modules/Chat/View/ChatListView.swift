//
//  ChatListView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI
import FirebaseAuth

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showNewChat = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.recentChats.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                } else if viewModel.recentChats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        Text("Tap the pencil icon to start a new chat")
                            .font(.subheadline)
                            .foregroundStyle(.gray.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.recentChats) { recentChat in
                            // Only show valid chats
                            if let otherUser = recentChat.otherUser,
                               let currentUserId = Auth.auth().currentUser?.uid {
                                NavigationLink {
                                    ChatDetailView(otherUser: otherUser)
                                } label: {
                                    RecentChatRowView(
                                        recentChat: recentChat,
                                        currentUserId: currentUserId
                                    )
                                    .contentShape(Rectangle()) // Make full row tappable
                                }
                                .buttonStyle(.plain) // Remove default list button style
                                
                                Divider()
                                    .padding(.leading, 78) // Indent divider to match avatar
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .background(Color(.systemGroupedBackground)) // Subtle background
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.primary)
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                UserListView()
            }
            .onAppear {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }
}

struct RecentChatRowView: View {
    let recentChat: RecentChat
    let currentUserId: String
    
    private var formattedTime: String {
        guard let date = recentChat.chat.lastMessageTimestamp else { return "" }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MM/dd/yy"
        }
        return formatter.string(from: date)
    }
    
    private var unreadCount: Int {
        recentChat.chat.getUnreadCount(for: currentUserId)
    }
    
    private var hasUnread: Bool {
        unreadCount > 0
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar with badge overlay
            ZStack(alignment: .topTrailing) {
                if let user = recentChat.otherUser {
                    AsyncImage(url: URL(string: user.photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.gray.opacity(0.3))
                }
                
                // Unread badge (red dot)
                if hasUnread {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(recentChat.otherUser?.name ?? "Unknown User")
                        .font(.headline)
                        .fontWeight(hasUnread ? .bold : .regular)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(formattedTime)
                        .font(.caption)
                        .foregroundStyle(hasUnread ? .primary : .secondary)
                        .fontWeight(hasUnread ? .semibold : .regular)
                }
                
                Text(recentChat.chat.lastMessage ?? "No messages")
                    .font(.subheadline)
                    .foregroundStyle(hasUnread ? .primary : .secondary)
                    .fontWeight(hasUnread ? .medium : .regular)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    ChatListView()
}
