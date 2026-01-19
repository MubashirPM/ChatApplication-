//
//  TabBarView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 19/01/26.
//

import Foundation
import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        TabView {
            ChatListView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }
            
            SignOutView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}   
