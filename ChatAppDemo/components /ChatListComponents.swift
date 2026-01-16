//
//  ChatListComponents.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//
import SwiftUI
struct ChatListComponents: View {
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image("Image")
                    .resizable()
                    .frame(width: 50,height: 50)
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text("Mubashir")
                        .font(.headline)
                    Text("Pm")
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                }
            }
        }
        .padding(.vertical)
    }
}
