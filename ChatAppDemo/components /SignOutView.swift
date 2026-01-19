//
//  SignOutView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 19/01/26.
//

import SwiftUI

struct SignOutView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // User Avatar
                        AsyncImage(url: URL(string: authViewModel.currentUser?.photoURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.gray)
                                .font(.system(size: 80))
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.peach, lineWidth: 3))
                        .shadow(radius: 5)
                        
                        // User Name
                        if let name = authViewModel.currentUser?.name {
                            Text(name)
                                .font(.title2)
                                .bold()
                        }
                        
                        // User Email - Displayed prominently
                        if let email = authViewModel.currentUser?.email {
                            VStack(spacing: 8) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Error Message Display
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    // Sign Out Button
                    Button {
                        authViewModel.signOut()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.white)
                                .font(.title3)
                            
                            Text("Sign Out")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        // React to auth state changes - automatically redirects when signed out
        // The app will automatically navigate based on isAuthenticated state
        // This is handled in ChatAppDemoApp
    }
}

#Preview {
    let authViewModel = AuthenticationViewModel()
    // Set a mock user for preview
    authViewModel.currentUser = UserModel(
        id: "preview-user",
        name: "John Doe",
        email: "john.doe@example.com",
        photoURL: "",
        createdAt: Date()
    )
    
    return SignOutView()
        .environmentObject(authViewModel)
}
