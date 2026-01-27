//
//  UserListView.swift
//  ChatAppDemo
//
//  Created by Antigravity on 21/01/26.
//

import SwiftUI
import FirebaseAuth

struct UserListView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject private var userManager = UserManager()
    @Environment(\.dismiss) var dismiss
    
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
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Get current user ID
                let currentUserId = Auth.auth().currentUser?.uid ?? authViewModel.currentUser?.id
                if let currentUserId = currentUserId {
                    userManager.fetchUsers(excludingUserId: currentUserId)
                }
            }
        }
    }
}

#Preview {
    UserListView()
        .environmentObject(AuthenticationViewModel())
}
