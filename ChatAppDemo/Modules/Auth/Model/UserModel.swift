//
//  UserModel.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Foundation
import FirebaseFirestore

/// Model representing a user in the Firestore database
struct UserModel: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let email: String
    let photoURL: String
    let createdAt: Date
    let isOTPVerified: Bool? // Track if user has completed OTP verification
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case photoURL
        case createdAt
        case isOTPVerified
    }
}
