//
//  MessageBubble.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 14/01/26.
//

import SwiftUI

struct MessageBubble: View {
    var message: Message
    var isFromCurrentUser: Bool
    @State private var showTime = false
    
    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading) {
            HStack {
                Text(message.text)
                    .padding()
                    .background(isFromCurrentUser ? Color("peach") : Color("Gray"))
                    .cornerRadius(30)
            }
            .frame(maxWidth: 300, alignment: isFromCurrentUser ? .trailing : .leading)
            .onTapGesture {
                showTime.toggle()
            }
            
            if showTime {
                Text("\(message.timestamp.formatted(.dateTime.hour().minute()))")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .padding(isFromCurrentUser ? .trailing : .leading, 25)
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .padding(.horizontal, 10)
    }
}

#Preview {
    VStack {
        MessageBubble(
            message: Message(
                id: "1234",
                text: "i have been creating swiftui application from crash and it is have fun",
                senderId: "sender",
                receiverId: "receiver",
                timestamp: Date()
            ),
            isFromCurrentUser: true
        )
        
        MessageBubble(
            message: Message(
                id: "1235",
                text: "That's great! Keep it up!",
                senderId: "receiver",
                receiverId: "sender",
                timestamp: Date()
            ),
            isFromCurrentUser: false
        )
    }
}
