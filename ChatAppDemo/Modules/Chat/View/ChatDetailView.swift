//
//  ChatDetailView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI

struct ChatDetailView: View {
    @StateObject var messagesManager = MessaageManagaer()

    var body: some View {
        VStack {
            VStack {
                TitleComponent()
                
                ScrollView {
                    ForEach(messagesManager.messages,id: \.id){ message in
                        MessageBubble(message: message)
                    }
                }
                .padding(.top,10)
                .background(Color.white)
                .cornerRadius(30, corners: [.topLeft,.topRight])
            }
            .background(Color("peach"))
            
            MessageField()
                .environmentObject(MessaageManagaer())
        }
    }
}

#Preview {
    ChatDetailView()
}
