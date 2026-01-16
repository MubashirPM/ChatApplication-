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
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording {
                            isRecording = true
                            _ = recorder.startRecording()
                        }
                    }
                    .onEnded { _ in
                        if isRecording {
                            isRecording = false
                            let (audioURL, duration) = recorder.stopRecording()
                            
                            // Only send if recording duration is more than 0.5 seconds
                            if let url = audioURL, duration > 0.5 {
                                Task {
                                    await chatManager.sendVoiceMessage(
                                        audioURL: url,
                                        duration: duration,
                                        chatId: chatId,
                                        senderId: senderId,
                                        receiverId: receiverId
                                    )
                                }
                            } else if let url = audioURL {
                                // Cancel if too short
                                recorder.cancelRecording()
                                try? FileManager.default.removeItem(at: url)
                            }
                        }
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
