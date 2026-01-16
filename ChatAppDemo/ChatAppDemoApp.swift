//
//  ChatAppDemoApp.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 13/01/26.
//

import SwiftUI
import FirebaseCore

@main
struct ChatAppDemoApp: App {
    
    init(){
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ChatDetailView()
        }
    }
}
