//
//  ChatListView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI

struct ChatListView: View {
    let count = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    ChatListComponents()

                    if index < count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal,16)
            
        }
    }
}


#Preview {
    ChatListView()
}
