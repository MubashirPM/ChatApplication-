//
//  ChatListView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject private var userManager = UserManager()
    @State private var selectedUserId: String?
    @State private var navigateToChat = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if userManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if userManager.users.isEmpty {
                        Text("No users available")
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(userManager.users) { user in
                            NavigationLink {
                                ChatDetailView(otherUser: user)
                            } label: {
                                ChatListRowView(user: user)
                            }
                            
                            if user.id != userManager.users.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Chats")
            .onAppear {
                if let currentUserId = authViewModel.currentUser?.id {
                    userManager.fetchUsers(excludingUserId: currentUserId)
                }
            }
        }
    }
}

// MARK: - Chat List Row View

struct ChatListRowView: View {
    let user: UserModel
    
    var body: some View {
        HStack(spacing: 12) {
            // User Avatar
            AsyncImage(url: URL(string: user.photoURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ChatListView()
        .environmentObject(AuthenticationViewModel())
}
