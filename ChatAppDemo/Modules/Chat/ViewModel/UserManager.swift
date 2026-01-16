//
//  UserManager.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Foundation
import FirebaseFirestore
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
                
                self.users = documents.compactMap { document -> UserModel? in
                    do {
                        let user = try document.data(as: UserModel.self)
                        // Exclude current user if provided
                        if let excludingUserId = excludingUserId, user.id == excludingUserId {
                            return nil
                        }
                        return user
                    } catch {
                        debugPrint("Error decoding user: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                self.isLoading = false
            }
    }
    
    /// Get user by ID
    func getUser(byId userId: String) -> UserModel? {
        users.first { $0.id == userId }
    }
}
