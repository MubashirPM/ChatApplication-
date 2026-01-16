//
//  MessageFieldView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import SwiftUI

struct MessageFieldView: View {
    let chatId: String
    let senderId: String
    let receiverId: String
    
    @EnvironmentObject var chatManager: ChatManager
    @StateObject private var recorder = AudioRecorder()
    @State private var isRecording = false
    @State private var message = ""
    
    var body: some View {
        HStack(spacing: 10) {
            CustomTextField(
                placeholder: "Enter your message here",
                text: $message
            )
            
            // Voice Record Button
            Button {} label: {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(isRecording ? Color.red : Color.gray)
                    .cornerRadius(50)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording {
                            isRecording = true
                            recorder.startRecording()
                        }
                    }
                    .onEnded { _ in
                        isRecording = false
                        recorder.stopRecording()
                    }
            )
            
            // Send Message Button
            Button {
                if !message.trimmingCharacters(in: .whitespaces).isEmpty {
                    chatManager.sendMessage(
                        text: message,
                        chatId: chatId,
                        senderId: senderId,
                        receiverId: receiverId
                    )
                    message = ""
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color("peach"))
                    .cornerRadius(50)
            }
            .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
}


#Preview {
    MessageFieldView(
        chatId: "test",
        senderId: "sender",
        receiverId: "receiver"
    )
    .environmentObject(ChatManager())
}
