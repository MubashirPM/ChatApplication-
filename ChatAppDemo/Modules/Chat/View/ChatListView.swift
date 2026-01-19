//
//  ChatListView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI
import FirebaseAuth

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
                // Get current user ID from Firebase Auth (most reliable) or from currentUser model
                let currentUserId = Auth.auth().currentUser?.uid ?? authViewModel.currentUser?.id
                
                if let currentUserId = currentUserId {
                    userManager.fetchUsers(excludingUserId: currentUserId)
                    
                    // Clean up invalid users on first load
                    Task {
                        await userManager.cleanupInvalidUsers()
                        // Refresh users after cleanup
                        await MainActor.run {
                            // Re-fetch current user ID in case it changed
                            let refreshedUserId = Auth.auth().currentUser?.uid ?? authViewModel.currentUser?.id
                            if let refreshedUserId = refreshedUserId {
                                userManager.fetchUsers(excludingUserId: refreshedUserId)
                            }
                        }
                    }
                } else {
                    // No current user, just fetch all users (they'll be filtered in UserManager)
                    userManager.fetchUsers(excludingUserId: nil)
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
