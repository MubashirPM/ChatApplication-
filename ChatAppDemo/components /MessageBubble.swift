//
//  MessageBubble.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 14/01/26.
//

import SwiftUI

struct MessageBubble: View {
    var message : Message
    @State private var showTime = false
    
    var body: some View {
        VStack(alignment: message.received ?.leading : .trailing) {
            HStack {
                Text(message.text)
                    .padding()
                    .background(message.received ? Color("Gray") : Color("peach"))
                    .cornerRadius(30)
            }
            .frame(maxWidth: 300,alignment: message.received ? .leading : .trailing)
            .onTapGesture {
                showTime.toggle()
            }
            if showTime {
                Text("\(message.timestamp.formatted(.dateTime.hour().minute()))")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .padding(message.received ? .leading : .trailing,25)
            }
        }
        .frame(maxWidth: .infinity,alignment: message.received ? .leading : .trailing)
        .padding(.horizontal,10)
    }
}

#Preview {
    MessageBubble(message: Message(id: "1234", text: "i have been creating swiftui application from crash and it is have fun ", received: false, timestamp: Date()))
}
