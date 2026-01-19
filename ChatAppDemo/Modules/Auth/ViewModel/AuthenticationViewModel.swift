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
// TODO: Add FacebookLogin SDK package dependency in Xcode
// import FacebookLogin
import Combine

/// ViewModel managing authentication state and Google Sign-In
@MainActor
class AuthenticationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var currentUser: UserModel?
    
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
                        self.isAuthenticated = true
                        self.saveAuthenticationState(true)
                        await self.loadCurrentUserFromFirestore(userId: user.uid)
                        
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
            isAuthenticated = true
            saveAuthenticationState(true)
            await loadCurrentUserFromFirestore(userId: user.uid)
            
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
            
            // Load current user info
            await loadCurrentUserFromFirestore(userId: firebaseUser.uid)
            
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
    
    // MARK: - Facebook Sign-In
    
    /// Sign in with Facebook using Firebase Auth
    /// Note: Requires FacebookLogin SDK to be added to the project
    func signInWithFacebook() async {
        isLoading = true
        errorMessage = nil
        
        // TODO: Uncomment after adding FacebookLogin SDK package dependency
        /*
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to find root view controller"
            isLoading = false
            return
        }
        
        do {
            // Request Facebook login permissions
            let loginManager = LoginManager()
            let result = try await loginManager.logIn(permissions: ["email", "public_profile"], from: rootViewController)
            
            guard let token = result.token?.tokenString else {
                errorMessage = "Failed to get Facebook access token"
                isLoading = false
                return
            }
            
            // Create Firebase credential with Facebook token
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            
            // Sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user
            
            // Save user to Firestore
            await saveUserToFirestore(user: firebaseUser)
            
            // Load current user info
            await loadCurrentUserFromFirestore(userId: firebaseUser.uid)
            
            // Save authentication state
            saveAuthenticationState(true)
            isLoading = false
            
        } catch {
            if let loginError = error as? LoginError {
                switch loginError {
                case .cancelled:
                    errorMessage = "Sign in was cancelled"
                default:
                    errorMessage = "Facebook sign in failed: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            isLoading = false
        }
        */
        
        // Temporary: Alternative implementation using web-based Facebook login
        // This doesn't require Facebook SDK but uses a web view
        await signInWithFacebookWebFlow()
    }
    
    /// Sign in with Facebook using web-based flow (alternative to SDK)
    /// This uses Firebase's OAuthProvider for Facebook authentication
    private func signInWithFacebookWebFlow() async {
        // Note: For production, it's recommended to use FacebookLogin SDK
        // This is a simplified implementation using Firebase's OAuthProvider
        
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to find root view controller"
            isLoading = false
            return
        }
        
        // Get Facebook App ID from Info.plist
        // You need to add FacebookAppID to Info.plist
        guard let facebookAppID = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String,
              !facebookAppID.isEmpty else {
            errorMessage = "Facebook App ID not configured. Please add FacebookAppID to Info.plist"
            debugPrint("Please add FacebookAppID to Info.plist with your Facebook App ID")
            isLoading = false
            return
        }
        
        // Use Firebase's OAuthProvider for Facebook
        let provider = OAuthProvider(providerID: "facebook.com")
        provider.scopes = ["email", "public_profile"]
        provider.customParameters = [
            "display": "popup"
        ]
        
        do {
            // Sign in with OAuth provider
            // OAuthProvider uses getCredentialWith method with delegate
            let credential = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthCredential, Error>) in
                // Create a delegate wrapper for the view controller
                let authUIDelegate = AuthUIDelegateWrapper(viewController: rootViewController)
                
                // Use getCredentialWith with the delegate (first parameter is the delegate)
                provider.getCredentialWith(authUIDelegate) { credential, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let credential = credential {
                        continuation.resume(returning: credential)
                    } else {
                        continuation.resume(throwing: NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get credential"]))
                    }
                }
            }
            
            // Sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user
            
            // Save user to Firestore
            await saveUserToFirestore(user: firebaseUser)
            
            // Load current user info
            await loadCurrentUserFromFirestore(userId: firebaseUser.uid)
            
            // Save authentication state
            saveAuthenticationState(true)
            isLoading = false
            
        } catch {
            let nsError = error as NSError
            
            // Check if it's a cancellation error (usually code 2001 or domain contains "cancel")
            if nsError.domain.contains("cancel") || nsError.code == 2001 {
                errorMessage = "Facebook sign in was cancelled"
            } else if nsError.domain == "FIRAuthErrorDomain", 
                      let errorCode = AuthErrorCode(rawValue: nsError.code) {
                switch errorCode {
                case .userNotFound,
                     .userDisabled,
                     .invalidCredential:
                    errorMessage = "Facebook sign in failed: \(error.localizedDescription)"
                default:
                    errorMessage = "Facebook sign in failed: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Facebook sign in failed: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    /// Sign out the current user
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            
            // Clear local state
            currentUser = nil
            saveAuthenticationState(false)
            errorMessage = nil
            
            debugPrint("User signed out successfully")
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
            debugPrint("Sign out error: \(error.localizedDescription)")
        }
    }
}

// MARK: - AuthUIDelegate Wrapper

/// Wrapper to make UIViewController conform to AuthUIDelegate
private class AuthUIDelegateWrapper: NSObject, AuthUIDelegate {
    weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
    }
    
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        viewController?.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        viewController?.dismiss(animated: flag, completion: completion)
    }
}
