//
//  AuthenticationViewModel.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import Combine

/// ViewModel managing authentication state and Google Sign-In
@MainActor
class AuthenticationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let authStateKey = "isAuthenticated"
    
    // MARK: - Initialization
    
    init() {
        checkAuthenticationState()
    }
    
    // MARK: - Authentication State Management
    
    /// Check if user is authenticated via UserDefaults and Firebase Auth
    func checkAuthenticationState() {
        let savedAuthState = UserDefaults.standard.bool(forKey: authStateKey)
        let currentUser = Auth.auth().currentUser
        
        isAuthenticated = savedAuthState && currentUser != nil
        
        if !isAuthenticated && savedAuthState {
            // UserDefaults says authenticated but Firebase doesn't, reset state
            UserDefaults.standard.set(false, forKey: authStateKey)
        }
    }
    
    /// Save authentication state to UserDefaults
    private func saveAuthenticationState(_ authenticated: Bool) {
        UserDefaults.standard.set(authenticated, forKey: authStateKey)
        isAuthenticated = authenticated
    }
    
    // MARK: - Google Sign-In
    
    /// Sign in with Google using native iOS flow
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        // First, try to restore previous sign-in (if user was signed in before)
        do {
            let restoredUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            // User was already signed in, use their credentials
            await handleGoogleSignInResult(user: restoredUser)
            return
        } catch {
            // No previous sign-in, continue with new sign-in flow
            debugPrint("No previous sign-in to restore: \(error.localizedDescription)")
        }
        
        // Get root view controller for presenting sign-in
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to find root view controller"
            isLoading = false
            return
        }
        
        do {
            // Attempt native iOS sign-in flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            await handleGoogleSignInResult(user: result.user)
            
        } catch {
            let nsError = error as NSError
            
            // Handle specific error cases
            if let signInError = error as? GIDSignInError {
                switch signInError.code {
                case .canceled:
                    errorMessage = "Sign in was cancelled"
                case .hasNoAuthInKeychain:
                    errorMessage = "No authentication found"
                default:
                    errorMessage = "Sign in failed: \(signInError.localizedDescription)"
                }
            } else {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    /// Handle Google Sign-In result and authenticate with Firebase
    private func handleGoogleSignInResult(user: GIDGoogleUser) async {
        guard let idToken = user.idToken?.tokenString else {
            errorMessage = "Failed to get ID token"
            isLoading = false
            return
        }
        
        do {
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user
            
            // Save user to Firestore
            await saveUserToFirestore(user: firebaseUser)
            
            // Save authentication state
            saveAuthenticationState(true)
            isLoading = false
            
        } catch {
            errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Firestore User Management
    
    /// Save or update user in Firestore Users collection
    private func saveUserToFirestore(user: User) async {
        let userRef = db.collection("Users").document(user.uid)
        
        do {
            let documentSnapshot = try await userRef.getDocument()
            
            if documentSnapshot.exists {
                // User already exists, update if needed
                try await userRef.updateData([
                    "email": user.email ?? "",
                    "name": user.displayName ?? "",
                    "photoURL": user.photoURL?.absoluteString ?? ""
                ])
            } else {
                // Create new user document
                let userModel = UserModel(
                    id: user.uid,
                    name: user.displayName ?? "",
                    email: user.email ?? "",
                    photoURL: user.photoURL?.absoluteString ?? "",
                    createdAt: Date()
                )
                
                try userRef.setData(from: userModel)
            }
        } catch {
            debugPrint("Error saving user to Firestore: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sign Out
    
    /// Sign out the current user
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            saveAuthenticationState(false)
            errorMessage = nil
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}
