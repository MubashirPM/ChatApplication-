//
//  ChatAppDemoApp.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 13/01/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct ChatAppDemoApp: App {
    
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    init() {
        FirebaseApp.configure()
        
        // Configure Google Sign-In with the client ID from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientID = plist["CLIENT_ID"] as? String else {
            fatalError("GoogleService-Info.plist not found or CLIENT_ID missing")
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ChatListView()
                } else {
                    AutheticationView()
                }
            }
            .environmentObject(authViewModel)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
