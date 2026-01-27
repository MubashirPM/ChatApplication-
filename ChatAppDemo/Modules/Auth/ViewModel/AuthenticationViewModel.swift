//
//  AuthenticationViewModel.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Foundation
import SwiftUI
import UIKit
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
    @Published var currentUser: UserModel?
    @Published var needsOTPVerification = false // New: Track if OTP verification is needed
    @Published var isInitializing = true // Track if initial auth check is in progress
    @Published var isAuthenticating = false // Track if authentication flow is in progress (prevents UI flicker)
    
    // Track pending Google user for OTP-first flow
    private var pendingGoogleUser: GIDGoogleUser?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let authStateKey = "isAuthenticated"
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    
    init() {
        setupAuthStateListener()
        Task {
            await validateAndCheckAuthenticationState()
        }
    }
    
    deinit {
        // Remove auth state listener when ViewModel is deallocated
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Authentication State Management
    
    /// Setup Firebase Auth state listener to detect auth changes (including user deletion)
    /// This listener fires whenever auth state changes, including when user is deleted
    private func setupAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let user = user {
                    // User is signed in - verify they still exist
                    // Use reload() to check if user still exists on server
                    do {
                        // Reload user data from server
                        try await user.reload()
                        
                        // Get fresh token to ensure it's valid
                        _ = try await user.getIDToken(forcingRefresh: false)
                        
                        // User exists and is valid
                        // Load user data
                        await self.loadCurrentUserFromFirestore(userId: user.uid)
                        
                        // Check if user is already authenticated in current session
                        // If yes, keep authenticated (session persists)
                        // If no, they need to sign in again (which will require OTP)
                        if self.isAuthenticated && !self.needsOTPVerification {
                            // User is already authenticated in current session, keep authenticated
                            // This handles app state restoration without requiring OTP again
                        } else {
                            // User is not authenticated, but don't set needsOTPVerification here
                            // OTP will be required when they sign in (handled in saveUserToFirestore)
                            self.isAuthenticated = false
                            self.needsOTPVerification = false
                        }
                        
                    } catch let error as NSError {
                        // Check if error is due to user being deleted/disabled
                        if error.domain == "FIRAuthErrorDomain", 
                           let authErrorCode = AuthErrorCode(rawValue: error.code) {
                            
                            switch authErrorCode {
                            case .userTokenExpired,
                                 .invalidUserToken,
                                 .userDisabled,
                                 .userNotFound:
                                // User deleted, disabled, or token invalid
                                debugPrint("User deleted or invalid: \(error.localizedDescription)")
                                self.handleUserDeleted()
                                
                            case .networkError:
                                // Network error - keep user signed in
                                // Don't force logout on network errors
                                debugPrint("Network error during auth state change: \(error.localizedDescription)")
                                // Keep current authentication state
                                
                            default:
                                // Other auth errors - sign out for safety
                                debugPrint("Auth error: \(error.localizedDescription)")
                                self.handleUserDeleted()
                            }
                        } else {
                            // Non-auth error - log but keep user signed in
                            debugPrint("Non-auth error during state change: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // No user - signed out or deleted
                    debugPrint("No user in auth state - signing out")
                    self.handleUserDeleted()
                }
            }
        }
    }
    
    /// Handle user deletion or sign out
    /// Called when user is deleted from Firebase Console or signs out
    private func handleUserDeleted() {
        debugPrint("User deleted or signed out - redirecting to login")
        
        // Get user ID before clearing to clean up Firestore
        let userIdToDelete = currentUser?.id ?? Auth.auth().currentUser?.uid
        
        // Sign out from Firebase Auth first
        do {
            try Auth.auth().signOut()
        } catch {
            debugPrint("Error signing out from Firebase Auth: \(error.localizedDescription)")
        }
        
        // Sign out from Google Sign-In as well
        GIDSignIn.sharedInstance.signOut()
        
        // Clear authentication state
        isAuthenticated = false
        needsOTPVerification = false
        isAuthenticating = false
        currentUser = nil
        UserDefaults.standard.set(false, forKey: authStateKey)
        errorMessage = nil
        
        // Clean up user document from Firestore if user was deleted
        if let userId = userIdToDelete {
            Task {
                await deleteUserFromFirestore(userId: userId)
            }
        }
        
        // Optionally show a message (commented out to avoid interrupting user)
        // errorMessage = "Session expired. Please sign in again."
    }
    
    /// Delete user document from Firestore
    private func deleteUserFromFirestore(userId: String) async {
        let userRef = db.collection("Users").document(userId)
        
        do {
            try await userRef.delete()
            debugPrint("User document deleted from Firestore: \(userId)")
        } catch {
            debugPrint("Error deleting user from Firestore: \(error.localizedDescription)")
        }
    }
    
    /// Validate user existence and check authentication state on app launch
    /// This ensures that if a user was deleted from Firebase Console, they are logged out
    private func validateAndCheckAuthenticationState() async {
        defer {
            // Always set isInitializing to false when function completes
            isInitializing = false
        }
        
        guard let user = Auth.auth().currentUser else {
            // No user in cache, check UserDefaults
            let savedAuthState = UserDefaults.standard.bool(forKey: authStateKey)
            if savedAuthState {
                // UserDefaults says authenticated but no user exists, reset state
                UserDefaults.standard.set(false, forKey: authStateKey)
            }
            isAuthenticated = false
            currentUser = nil
            return
        }
        
        // User exists in cache - validate they still exist in Firebase Auth
        // Use reload() to fetch latest user data from server
        do {
            // Force reload user data from Firebase Auth server
            // This will fail if user was deleted from Firebase Console
            try await user.reload()
            
            // Force token refresh to ensure token is valid
            // This will also fail if user was deleted or disabled
            _ = try await user.getIDToken(forcingRefresh: true)
            
            // User exists and is valid
            // Load user data
            await loadCurrentUserFromFirestore(userId: user.uid)
            
            // Check if user was already authenticated in previous session
            // If yes, keep them authenticated (session persists)
            // If no, they need to sign in again (which will require OTP)
            let savedAuthState = UserDefaults.standard.bool(forKey: authStateKey)
            if savedAuthState {
                // User was authenticated in previous session, keep authenticated
                // This allows session to persist across app launches
                isAuthenticated = true
                needsOTPVerification = false
            } else {
                // User was not authenticated, require new login (which will require OTP)
                isAuthenticated = false
                needsOTPVerification = false
            }
            
            debugPrint("User validated successfully: \(user.uid)")
            
        } catch let error as NSError {
            debugPrint("User validation failed: \(error.localizedDescription)")
            
            // Check if error is due to user being deleted/disabled
            if error.domain == "FIRAuthErrorDomain", 
               let authErrorCode = AuthErrorCode(rawValue: error.code) {
                
                switch authErrorCode {
                case .userTokenExpired,
                     .invalidUserToken,
                     .userDisabled,
                     .userNotFound:
                    // User deleted, disabled, or token invalid - force logout
                    debugPrint("User deleted or invalid - forcing logout")
                    handleUserDeleted()
                    return
                    
                case .networkError:
                    // Network error - keep user signed in but don't update state
                    // We'll retry later when network is available
                    debugPrint("Network error during validation - keeping current state")
                    let savedAuthState = UserDefaults.standard.bool(forKey: authStateKey)
                    isAuthenticated = savedAuthState
                    if savedAuthState {
                        await loadCurrentUserFromFirestore(userId: user.uid)
                    }
                    return
                    
                default:
                    // Unknown auth error - sign out for safety
                    debugPrint("Unknown auth error - forcing logout for safety")
                    handleUserDeleted()
                    return
                }
            } else {
                // Non-auth error - sign out for safety if it's a critical error
                debugPrint("Non-auth error during validation: \(error.domain)")
                // Only sign out if it's a critical error, otherwise keep current state
                let savedAuthState = UserDefaults.standard.bool(forKey: authStateKey)
                isAuthenticated = savedAuthState
                if savedAuthState {
                    await loadCurrentUserFromFirestore(userId: user.uid)
                }
            }
        }
    }
    
    /// Check if user is authenticated via UserDefaults and Firebase Auth
    /// This is a simpler check for UI state, not for validation
    private func checkAuthenticationState() {
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
        isAuthenticating = true // Prevent UI flicker during transition
        errorMessage = nil
        
        // First, try to restore previous sign-in (if user was signed in before)
        do {
            let restoredUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            // User was already signed in, store for OTP verification
            pendingGoogleUser = restoredUser
            
            // Show OTP screen first
            needsOTPVerification = true
            isLoading = false
            // Keep isAuthenticating = true until OTP is verified
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
            isAuthenticating = false
            return
        }
        
        do {
            // Attempt native iOS sign-in flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            // Store the Google user for later Firebase authentication (after OTP)
            pendingGoogleUser = result.user
            
            // Show OTP screen first, before Firebase authentication
            needsOTPVerification = true
            isLoading = false
            // Keep isAuthenticating = true until OTP is verified
            
            debugPrint("✅ Google sign-in successful, showing OTP screen")
            
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
            isAuthenticating = false // Reset on error
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
            
            debugPrint("✅ Google authentication successful for user: \(firebaseUser.uid)")
            
            // Save user to Firestore (this will check OTP status and set needsOTPVerification if needed)
            await saveUserToFirestore(user: firebaseUser)
            
            // Load current user info
            await loadCurrentUserFromFirestore(userId: firebaseUser.uid)
            
            // saveUserToFirestore sets needsOTPVerification = true
            // This will show the OTP view next
            isLoading = false
            
            debugPrint("➡️  Navigating to OTP verification view")
            
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
                // User already exists - update basic info
                // Always require OTP verification on every login
                try await userRef.updateData([
                    "email": user.email ?? "",
                    "name": user.displayName ?? "",
                    "photoURL": user.photoURL?.absoluteString ?? "",
                    "isOTPVerified": false // Reset OTP verification status on each login
                ])
                
                // Always require OTP verification for every login
                needsOTPVerification = true
            } else {
                // Create new user document (first time login)
                let userModel = UserModel(
                    id: user.uid,
                    name: user.displayName ?? "",
                    email: user.email ?? "",
                    photoURL: user.photoURL?.absoluteString ?? "",
                    createdAt: Date(),
                    isOTPVerified: false // New user, OTP not verified yet
                )
                
                try userRef.setData(from: userModel)
                
                // New user - require OTP verification
                needsOTPVerification = true
            }
        } catch {
            debugPrint("Error saving user to Firestore: \(error.localizedDescription)")
            // On error, require OTP for safety
            needsOTPVerification = true
        }
    }
    
    // MARK: - Current User Management
    
    /// Load current user from Firestore
    private func loadCurrentUser() {
        guard let userId = Auth.auth().currentUser?.uid else {
            currentUser = nil
            return
        }
        
        Task {
            await loadCurrentUserFromFirestore(userId: userId)
        }
    }
    
    /// Load user data from Firestore
    private func loadCurrentUserFromFirestore(userId: String) async {
        let userRef = db.collection("Users").document(userId)
        
        do {
            let document = try await userRef.getDocument()
            if document.exists {
                currentUser = try document.data(as: UserModel.self)
            }
        } catch {
            debugPrint("Error loading current user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User Validation
    
    /// Validate user existence when app appears
    /// Call this when app comes to foreground to check if user was deleted
    func validateUserOnAppAppear() async {
        // Only validate if user appears to be authenticated
        guard isAuthenticated, Auth.auth().currentUser != nil else {
            return
        }
        
        // Re-validate user existence
        await validateAndCheckAuthenticationState()
    }
    
    /// Sign out the current user
    func signOut() {
        // Get user ID before signing out (will be nil after signOut)
        let userId = Auth.auth().currentUser?.uid
        
        // Reset OTP verification status in Firestore before signing out
        if let userId = userId {
            Task {
                let userRef = db.collection("Users").document(userId)
                try? await userRef.updateData(["isOTPVerified": false])
            }
        }
        
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            
            // Clear local state
            currentUser = nil
            needsOTPVerification = false
            isAuthenticating = false
            saveAuthenticationState(false)
            errorMessage = nil
            
            debugPrint("User signed out successfully")
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
            debugPrint("Sign out error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - OTP Verification
    
    /// Verify OTP entered by user
    /// OTP is stored in Firestore Settings collection
    /// After successful verification, marks user as OTP verified in Firestore
    func verifyOTP(_ enteredOTP: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch OTP from Firestore Settings collection
            let settingsRef = db.collection("Settings").document("otp")
            let document = try await settingsRef.getDocument()
            
            let correctOTP: String
            if document.exists, let data = document.data(), let otp = data["code"] as? String {
                // OTP exists in Firestore
                correctOTP = otp
            } else {
                // Default OTP if not set in Firestore
                correctOTP = "1234"
                // Create default OTP document in Firestore
                try await settingsRef.setData(["code": correctOTP])
                debugPrint("Created default OTP in Firestore: \(correctOTP)")
            }
            
            // Verify entered OTP
            if enteredOTP == correctOTP {
                debugPrint("✅ OTP verified successfully")
                
                // Now complete Google authentication with Firebase
                if let googleUser = pendingGoogleUser {
                    debugPrint("➡️  Completing Google authentication with Firebase...")
                    await completeGoogleAuthenticationAfterOTP(user: googleUser)
                    
                    // Clear pending user
                    pendingGoogleUser = nil
                    // isAuthenticating is reset in completeGoogleAuthenticationAfterOTP
                } else {
                    // No pending Google user - this might be email/password login
                    // Just authenticate normally
                    guard let userId = Auth.auth().currentUser?.uid else {
                        errorMessage = "User not authenticated"
                        isLoading = false
                        isAuthenticating = false
                        return false
                    }
                    
                    // Mark user as verified in Firestore
                    let userRef = db.collection("Users").document(userId)
                    try await userRef.updateData([
                        "isOTPVerified": true
                    ])
                    
                    // Update local user model
                    if var user = currentUser {
                        // Create updated user with OTP verified flag
                        currentUser = UserModel(
                            id: user.id,
                            name: user.name,
                            email: user.email,
                            photoURL: user.photoURL,
                            createdAt: user.createdAt,
                            isOTPVerified: true
                        )
                    }
                    
                    // IMPORTANT: Update state in correct order to prevent UI flicker
                    // 1. Clear OTP requirement first
                    needsOTPVerification = false
                    
                    // 2. Then set authenticated (this will trigger navigation to TabBarView)
                    isAuthenticated = true
                    saveAuthenticationState(true)
                    
                    // 3. Clear authenticating state
                    isAuthenticating = false
                    
                    // 4. Finally clear loading
                    isLoading = false
                    
                    debugPrint("✅ OTP verified - navigating to TabBarView")
                }
                
                return true
            } else {
                // OTP is incorrect
                errorMessage = "Invalid OTP. Please try again."
                isLoading = false
                // Don't reset isAuthenticating - user is still in authentication flow
                debugPrint("❌ OTP verification failed: entered '\(enteredOTP)', expected '\(correctOTP)'")
                return false
            }
            
        } catch {
            errorMessage = "Error verifying OTP: \(error.localizedDescription)"
            isLoading = false
            isAuthenticating = false // Reset on error
            debugPrint("OTP verification error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Complete Google authentication with Firebase after OTP verification
    private func completeGoogleAuthenticationAfterOTP(user: GIDGoogleUser) async {
        guard let idToken = user.idToken?.tokenString else {
            errorMessage = "Failed to get ID token"
            isLoading = false
            isAuthenticating = false
            return
        }
        
        do {
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user
            
            debugPrint("✅ Firebase authentication successful for user: \(firebaseUser.uid)")
            
            // Create/update user in Firestore with OTP verified status
            let userRef = db.collection("Users").document(firebaseUser.uid)
            
            let documentSnapshot = try await userRef.getDocument()
            
            if documentSnapshot.exists {
                // User already exists - update with OTP verified
                try await userRef.updateData([
                    "email": firebaseUser.email ?? "",
                    "name": firebaseUser.displayName ?? "",
                    "photoURL": firebaseUser.photoURL?.absoluteString ?? "",
                    "isOTPVerified": true // Mark as verified since OTP was just verified
                ])
            } else {
                // Create new user document with OTP verified
                let userModel = UserModel(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "",
                    email: firebaseUser.email ?? "",
                    photoURL: firebaseUser.photoURL?.absoluteString ?? "",
                    createdAt: Date(),
                    isOTPVerified: true // Mark as verified since OTP was just verified
                )
                
                try userRef.setData(from: userModel)
            }
            
            // Load current user info
            await loadCurrentUserFromFirestore(userId: firebaseUser.uid)
            
            // Update state to complete authentication - ORDER MATTERS!
            // 1. Clear OTP requirement
            needsOTPVerification = false
            
            // 2. Set authenticated
            isAuthenticated = true
            saveAuthenticationState(true)
            
            // 3. Clear authenticating state
            isAuthenticating = false
            
            // 4. Finally clear loading
            isLoading = false
            
            debugPrint("✅ Authentication complete - navigating to TabBarView")
            
        } catch {
            errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
            isLoading = false
            isAuthenticating = false
            debugPrint("Firebase authentication error: \(error.localizedDescription)")
        }
    }
    
    /// Get current OTP from Firestore (for admin/debugging purposes)
    func getCurrentOTP() async -> String {
        do {
            let settingsRef = db.collection("Settings").document("otp")
            let document = try await settingsRef.getDocument()
            
            if document.exists, let data = document.data(), let otp = data["code"] as? String {
                return otp
            } else {
                return "1234" // Default OTP
            }
        } catch {
            debugPrint("Error fetching OTP: \(error.localizedDescription)")
            return "1234" // Default OTP on error
        }
    }
}

