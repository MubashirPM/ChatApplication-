//
//  MessageManager .swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 14/01/26.
//

import Foundation
import FirebaseFirestore
import Combine


class MessaageManagaer : ObservableObject {
    @Published private(set) var messages : [Message] = []
    
    let db = Firestore.firestore()
    
    init(){
        getMessages()
    }
    
    func getMessages(){
        db.collection("Message").addSnapshotListener { QuerySnapshot, error in
            guard let document = QuerySnapshot?.documents else {
                debugPrint("Error fetching documents : \(String(describing: error))")
                return
            }
            self.messages = document.compactMap { document -> Message? in
                do {
                    return try document.data(as: Message.self)
                } catch {
                    debugPrint("Error Decording document into Message: \(error)")
                    return nil
                }
            }
            self.messages.sort { $0.timestamp < $1.timestamp }
        }
    }
    func sentMessage(text: String, senderId: String, receiverId: String) {
        do {
            let newMessage = Message(
                id: nil,
                text: text,
                senderId: senderId,
                receiverId: receiverId,
                timestamp: Date()
            )
            try db.collection("Message").document().setData(from: newMessage)
        } catch {
            debugPrint("Error adding message to firestore: \(error)")
        }
    }
}
