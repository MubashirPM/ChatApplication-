//
//  UserManager.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// ViewModel for managing users list
@MainActor
class UserManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var users: [UserModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // MARK: - Initialization
    
    init() {
        fetchUsers()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Public Methods
    
    /// Fetch all users from Firestore (excluding current user)
    /// Only shows users who are currently authenticated in Firebase Auth
    /// Note: Since we can't directly verify user existence in Firebase Auth from client,
    /// we rely on Firestore being kept in sync. Users should be deleted from Firestore
    /// when they're deleted from Firebase Auth.
    func fetchUsers(excludingUserId: String? = nil) {
        isLoading = true
        
        listener = db.collection("Users")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Error fetching users: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.users = []
                    self.isLoading = false
                    return
                }
                
                // Filter users: exclude current user and only include users with valid data
                // Also verify users are valid by checking their data completeness
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // Get current Firebase Auth UID for comparison
                    let currentAuthUID = Auth.auth().currentUser?.uid
                    
                    var validUsers: [UserModel] = []
                    
                    for document in documents {
                        do {
                            let user = try document.data(as: UserModel.self)
                            
                            // Exclude current user by comparing:
                            // 1. Document ID (which should be Firebase Auth UID)
                            // 2. User.id field (from @DocumentID)
                            // 3. Current Firebase Auth UID
                            let documentId = document.documentID
                            let userId = user.id ?? documentId
                            
                            // Skip if this is the current user
                            if let excludingUserId = excludingUserId, 
                               (userId == excludingUserId || documentId == excludingUserId) {
                                continue
                            }
                            
                            // Also exclude if document ID or user ID matches current Firebase Auth UID
                            if let currentAuthUID = currentAuthUID,
                               (documentId == currentAuthUID || userId == currentAuthUID) {
                                continue
                            }
                            
                            // Only include users with valid ID and email
                            guard let userId = user.id, 
                                  !userId.isEmpty, 
                                  !user.email.isEmpty else {
                                // Invalid user data - might be deleted, skip
                                continue
                            }
                            
                            // Verify user has valid email format (must contain @)
                            guard user.email.contains("@"), 
                                  user.email.contains(".") else {
                                // Invalid email format - skip
                                debugPrint("Filtering out user with invalid email: \(user.email)")
                                continue
                            }
                            
                            // Verify user has a valid name (not empty, not just whitespace)
                            guard !user.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                // Invalid name - skip
                                debugPrint("Filtering out user with empty name: \(userId)")
                                continue
                            }
                            
                            // Verify email doesn't contain obvious test/invalid patterns
                            // Filter out emails that might be test data
                            let lowercasedEmail = user.email.lowercased()
                            if lowercasedEmail.contains("test") && 
                               !lowercasedEmail.contains("@") {
                                continue
                            }
                            
                            // Additional validation: Check if user has been created recently
                            // Users created too long ago without proper data might be invalid
                            // But we'll keep them for now and just verify data is valid
                            
                            validUsers.append(user)
                            
                        } catch {
                            debugPrint("Error decoding user: \(error.localizedDescription)")
                            continue
                        }
                    }
                    
                    self.users = validUsers
                    self.isLoading = false
                }
                
                self.isLoading = false
            }
    }
    
    /// Get user by ID
    func getUser(byId userId: String) -> UserModel? {
        users.first { $0.id == userId }
    }
    
    /// Clean up invalid users from Firestore
    /// Removes users that don't meet validation criteria
    /// This helps remove orphaned users that were deleted from Firebase Auth
    func cleanupInvalidUsers() async {
        do {
            let snapshot = try await db.collection("Users").getDocuments()
            
            var deletedCount = 0
            
            for document in snapshot.documents {
                do {
                    let user = try document.data(as: UserModel.self)
                    
                    // Check if user is invalid
                    var shouldDelete = false
                    
                    // Delete if no valid ID
                    if user.id == nil || user.id?.isEmpty == true {
                        shouldDelete = true
                        debugPrint("Deleting user with no ID: \(document.documentID)")
                    }
                    
                    // Delete if no email or invalid email format
                    if user.email.isEmpty || 
                       !user.email.contains("@") || 
                       !user.email.contains(".") {
                        shouldDelete = true
                        debugPrint("Deleting user with invalid email: \(user.email)")
                    }
                    
                    // Delete if name is empty
                    if user.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        shouldDelete = true
                        debugPrint("Deleting user with empty name: \(document.documentID)")
                    }
                    
                    if shouldDelete {
                        try await document.reference.delete()
                        deletedCount += 1
                        debugPrint("Deleted invalid user document: \(document.documentID)")
                    }
                } catch {
                    debugPrint("Error processing user for cleanup: \(error.localizedDescription)")
                }
            }
            
            debugPrint("Cleanup complete: Deleted \(deletedCount) invalid user(s)")
            
        } catch {
            debugPrint("Error cleaning up users: \(error.localizedDescription)")
        }
    }
    
    /// Delete a specific user from Firestore
    /// Use this to manually remove orphaned users
    func deleteUser(userId: String) async -> Bool {
        do {
            let userRef = db.collection("Users").document(userId)
            try await userRef.delete()
            debugPrint("Successfully deleted user from Firestore: \(userId)")
            return true
        } catch {
            debugPrint("Error deleting user from Firestore: \(error.localizedDescription)")
            return false
        }
    }
}
