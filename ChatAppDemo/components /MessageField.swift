////
////  MessageField.swift
////  ChatAppDemo
////
////  Created by Mubashir PM on 14/01/26.
////
//
//import SwiftUI
//
//struct MessageField: View {
//    @StateObject private var recorder = AudioRecorder()
//    @State private var isRecording = false
//
//    @EnvironmentObject var messagesManager : MessaageManagaer
//    @State private var message = ""
//    
//    var body: some View {
//        HStack {
//            CustomTextField(
//                placeholder: Text("Enter your message here"),
//                text: $message
//            )
//            
//            // Voice Record Button
//            Button {
//                // Empty action (gesture handles everything)
//            } label: {
//                Image(systemName: isRecording ? "mic.fill" : "mic")
//                    .foregroundStyle(.white)
//                    .padding(10)
//                    .background(isRecording ? Color.red : Color.gray)
//                    .cornerRadius(50)
//            }
//            .gesture(
//                LongPressGesture(minimumDuration: 0.1)
//                    .onChanged { _ in
//                        if !isRecording {
//                            isRecording = true
//                            recorder.startRecording()
//                        }
//                    }
//                    .onEnded { _ in
//                        isRecording = false
//                        recorder.stopRecording()
//                    }
//            )
//
//            // Send Text Message Button
//            Button {
//                messagesManager.sentMessage(text: message)
//                message = ""
//            } label: {
//                Image(systemName: "paperplane.fill")
//                    .foregroundStyle(.white)
//                    .padding(10)
//                    .background(Color("peach"))
//                    .cornerRadius(50)
//            }
//        }
//        
//        
//        #Preview {
//            MessageField()
//                .environmentObject(MessaageManagaer())
//        }
//        
//        struct CustomTextField: View {
//            let placeholder: String
//            @Binding var text: String
//
//            var body: some View {
//                ZStack(alignment: .leading) {
//
//                    if text.isEmpty {
//                        Text(placeholder)
//                            .foregroundColor(.gray)
//                    }
//
//                    TextField("", text: $text)
//                }
//            }
//        }
import SwiftUI

struct MessageField: View {
    let senderId: String
    let receiverId: String
    
    @StateObject private var recorder = AudioRecorder()
    @State private var isRecording = false
    @EnvironmentObject var messagesManager: MessaageManagaer
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
                messagesManager.sentMessage(text: message, senderId: senderId, receiverId: receiverId)
                message = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color("peach"))
                    .cornerRadius(50)
            }
        }
        .padding()
    }
}
