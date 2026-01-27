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
                if authViewModel.isInitializing {
                    // Show loading screen while checking authentication state
                    // This prevents the flash of login screen for logged-in users
                    ZStack {
                        Color.peach.opacity(0.1)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                } else if authViewModel.isAuthenticated {
                    // User is fully authenticated (OTP verified)
                    TabBarView()
                        .environmentObject(authViewModel)
                } else if authViewModel.needsOTPVerification {
                    // User signed in with Google but needs OTP verification
                    CustomizableOTPView() 
                        .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticating {
                    // Authentication in progress - show loading to prevent flicker
                    // This prevents showing login screen during state transitions
                    ZStack {
                        Color.peach.opacity(0.1)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Authenticating...")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                } else {
                    // Show login screen
                    AutheticationView()
                        .environmentObject(authViewModel)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onAppear {
                // Re-validate user when app appears
                // This ensures deleted users are detected even if app was in background
                Task {
                    await authViewModel.validateUserOnAppAppear()
                    
                    // Request notification permissions if authenticated
                    if authViewModel.isAuthenticated {
                        NotificationManager.shared.requestPermission()
                    }
                }
            }
        }
    }
}
